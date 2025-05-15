from flask import Flask, request, jsonify
import os
import csv
import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# === 🔐 CONFIGURATION ===
FIREBASE_CREDENTIALS_PATH = os.environ.get("FIREBASE_CREDENTIALS_PATH", "firebase-key.json")
GCP_API_KEY = os.environ.get("GCP_API_KEY", "")  # À configurer dans les variables d'environnement Render

# === 🔧 Initialisation Firebase ===
cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

# === Flask app ===
app = Flask(__name__)

# === 📤 Appel à l'API GCP Air Quality ===
def get_air_quality(lat, lon):
    url = f"https://airquality.googleapis.com/v1/currentConditions:lookup?key={GCP_API_KEY}"
    payload = {
        "location": {
            "latitude": float(lat),
            "longitude": float(lon)
        }
    }
    try:
        response = requests.post(url, json=payload)
        if response.status_code == 200:
            data = response.json()
            aqi = data.get("indexes", [{}])[0]
            pollutants = {p["code"]: p["concentration"]["value"] for p in data.get("pollutants", [])}
            return {
                "aqi_score": aqi.get("aqi"),
                "aqi_category": aqi.get("category"),
                "pollutants": pollutants
            }
        else:
            print(f"[ERREUR API] {response.status_code} → {response.text}")
            return None
    except Exception as e:
        print(f"[Exception API] {e}")
        return None

# === Routes API ===
@app.route('/health', methods=['GET'])
def health_check():
    """Point de terminaison pour vérifier que l'API fonctionne"""
    return jsonify({"status": "OK", "message": "API opérationnelle"}), 200

@app.route('/maj_ville', methods=['POST'])
def update_city():
    """Mettre à jour les données d'une seule ville"""
    try:
        data = request.json
        if not data or 'nom' not in data or 'lat' not in data or 'lon' not in data:
            return jsonify({"status": "ERROR", "message": "Données incomplètes"}), 400
        
        ville_code = data.get('code', data['nom'].lower().replace(' ', '_'))
        
        # Préparation des données de base
        ville_data = {
            "city": data["nom"],
            "country": data.get("country", "France"),
            "country_code": data.get("country_code", "FR"),
            "source": data.get("source", "API"),
            "coordinates": {"latitude": float(data["lat"]), "longitude": float(data["lon"])},
            "timestamp": datetime.utcnow().isoformat(),
        }
        
        # Ajout des données optionnelles si présentes
        for field in ["monuments", "shopping", "parcs_attractions"]:
            if field in data:
                if isinstance(data[field], list):
                    ville_data[field] = data[field]
                elif isinstance(data[field], str):
                    ville_data[field] = data[field].split('|')
        
        # Récupération de la qualité de l'air
        air_quality = get_air_quality(data["lat"], data["lon"])
        if air_quality:
            ville_data.update({
                "aqi_score": air_quality["aqi_score"],
                "aqi_category": air_quality["aqi_category"],
                "pollutants": air_quality["pollutants"]
            })
        else:
            ville_data.update({
                "aqi_score": None,
                "aqi_category": "Indisponible",
                "pollutants": {}
            })
        
        # Envoi vers Firestore
        db.collection("air_quality_data").document(ville_code).set(ville_data)
        return jsonify({
            "status": "OK", 
            "message": f"Ville {data['nom']} ajoutée avec succès",
            "code": ville_code
        }), 200
    
    except Exception as e:
        return jsonify({"status": "ERROR", "message": str(e)}), 500

@app.route('/maj_csv', methods=['POST'])
def update_from_csv():
    """Mettre à jour les données à partir d'un fichier CSV"""
    try:
        if 'file' not in request.files:
            return jsonify({"status": "ERROR", "message": "Aucun fichier fourni"}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({"status": "ERROR", "message": "Nom de fichier vide"}), 400
        
        # Traitement du CSV
        csv_content = file.read().decode('utf-8').splitlines()
        reader = csv.DictReader(csv_content)
        
        results = {"success": 0, "errors": []}
        
        for row in reader:
            try:
                if 'nom' not in row or 'lat' not in row or 'lon' not in row:
                    results["errors"].append(f"Ligne incomplète: {row}")
                    continue
                    
                ville_code = row.get('code', row['nom'].lower().replace(' ', '_'))
                
                # Préparation des données
                ville_data = {
                    "city": row["nom"],
                    "country": "France",
                    "country_code": "FR",
                    "source": row.get("source", "CSV"),
                    "coordinates": {"latitude": float(row["lat"]), "longitude": float(row["lon"])},
                    "timestamp": datetime.utcnow().isoformat(),
                }
                
                # Ajout des données optionnelles
                for field, target in [
                    ("monuments", "monuments"), 
                    ("shopping", "shopping"), 
                    ("parcs", "parcs_attractions")
                ]:
                    if field in row and row[field]:
                        ville_data[target] = row[field].split('|')
                
                # Récupération de la qualité de l'air
                air_quality = get_air_quality(row["lat"], row["lon"])
                if air_quality:
                    ville_data.update({
                        "aqi_score": air_quality["aqi_score"],
                        "aqi_category": air_quality["aqi_category"],
                        "pollutants": air_quality["pollutants"]
                    })
                else:
                    ville_data.update({
                        "aqi_score": None,
                        "aqi_category": "Indisponible",
                        "pollutants": {}
                    })
                
                # Envoi vers Firestore
                db.collection("air_quality_data").document(ville_code).set(ville_data)
                results["success"] += 1
                
            except Exception as e:
                results["errors"].append(f"Erreur pour {row.get('nom', 'ville inconnue')}: {str(e)}")
        
        return jsonify({
            "status": "OK",
            "message": f"{results['success']} villes mises à jour avec succès",
            "errors": results["errors"] if results["errors"] else None
        }), 200
    
    except Exception as e:
        return jsonify({"status": "ERROR", "message": str(e)}), 500

@app.route('/villes', methods=['GET'])
def get_cities():
    """Récupérer la liste des villes"""
    try:
        cities_ref = db.collection("air_quality_data")
        docs = cities_ref.stream()
        
        villes = []
        for doc in docs:
            data = doc.to_dict()
            villes.append({
                "code": doc.id,
                "nom": data.get("city"),
                "aqi_score": data.get("aqi_score"),
                "aqi_category": data.get("aqi_category"),
                "timestamp": data.get("timestamp")
            })
        
        return jsonify({"status": "OK", "villes": villes}), 200
    
    except Exception as e:
        return jsonify({"status": "ERROR", "message": str(e)}), 500

@app.route('/ville/<string:ville_code>', methods=['GET'])
def get_city_details(ville_code):
    """Récupérer les détails d'une ville spécifique"""
    try:
        doc_ref = db.collection("air_quality_data").document(ville_code)
        doc = doc_ref.get()
        
        if not doc.exists:
            return jsonify({"status": "ERROR", "message": "Ville non trouvée"}), 404
        
        return jsonify({"status": "OK", "data": doc.to_dict()}), 200
    
    except Exception as e:
        return jsonify({"status": "ERROR", "message": str(e)}), 500

if __name__ == '__main__':
    # Utilisation du port défini par Render ou 5000 par défaut
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
