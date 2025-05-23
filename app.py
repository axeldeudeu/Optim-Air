#!/usr/bin/env python3
"""
Web Service Flask pour récupérer les données Air Quality
Version Web Service gratuite pour Render
"""

from flask import Flask, jsonify, request
import os
import threading
import time
from datetime import datetime
import logging

# Import de notre logique principale
from main import AirQualityService

app = Flask(__name__)

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Variable globale pour le service
air_quality_service = None

def init_service():
    """Initialise le service Air Quality au démarrage"""
    global air_quality_service
    try:
        air_quality_service = AirQualityService()
        logger.info("✅ Service Air Quality initialisé")
        return True
    except Exception as e:
        logger.error(f"❌ Erreur initialisation service: {e}")
        return False

@app.route('/')
def health():
    """Endpoint de santé pour vérifier que le service fonctionne"""
    return jsonify({
        "status": "running",
        "service": "Air Quality Data Collector",
        "timestamp": datetime.now().isoformat(),
        "endpoints": {
            "/": "Health check",
            "/run": "Exécuter la collecte de données",
            "/run-sync": "Exécuter la collecte (synchrone)",
            "/status": "Statut du service"
        }
    })

@app.route('/status')
def status():
    """Retourne le statut détaillé du service"""
    global air_quality_service
    return jsonify({
        "service_initialized": air_quality_service is not None,
        "timestamp": datetime.now().isoformat(),
        "uptime": "Service running"
    })

@app.route('/run', methods=['GET', 'POST'])
def run_async():
    """Déclenche la collecte de données en arrière-plan (asynchrone)"""
    try:
        # Lance la collecte en arrière-plan
        thread = threading.Thread(target=collect_air_quality_data)
        thread.daemon = True
        thread.start()
        
        return jsonify({
            "status": "started",
            "message": "Collecte des données démarrée en arrière-plan",
            "timestamp": datetime.now().isoformat()
        }), 202
        
    except Exception as e:
        logger.error(f"Erreur lors du démarrage: {e}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

@app.route('/run-sync', methods=['GET', 'POST'])
def run_sync():
    """Déclenche la collecte de données de manière synchrone"""
    try:
        result = collect_air_quality_data()
        return jsonify({
            "status": "completed",
            "message": "Collecte des données terminée",
            "result": result,
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Erreur lors de l'exécution: {e}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

def collect_air_quality_data():
    """Fonction qui exécute la logique de collecte"""
    global air_quality_service
    
    try:
        if not air_quality_service:
            air_quality_service = AirQualityService()
        
        logger.info("🚀 Début de la collecte des données Air Quality")
        
        # Locations par défaut
        locations = [
            {"lat": 48.8566, "lng": 2.3522, "name": "Paris"},
            {"lat": 45.7640, "lng": 4.8357, "name": "Lyon"},
            {"lat": 43.2965, "lng": 5.3698, "name": "Marseille"},
            {"lat": 43.7102, "lng": 7.2620, "name": "Nice"},
            {"lat": 47.2184, "lng": -1.5536, "name": "Nantes"}
        ]
        
        # Locations depuis l'environnement si disponibles
        locations_env = os.getenv('LOCATIONS_JSON')
        if locations_env:
            import json
            try:
                locations = json.loads(locations_env)
                logger.info(f"Locations chargées: {len(locations)} locations")
            except json.JSONDecodeError:
                logger.warning("Erreur parsing locations, utilisation par défaut")
        
        # Collecte des données
        air_quality_data = air_quality_service.get_air_quality_data(locations)
        
        if not air_quality_data:
            logger.warning("Aucune donnée récupérée")
            return {"status": "warning", "message": "Aucune donnée récupérée"}
        
        # Sauvegarde
        air_quality_service.save_to_firebase(air_quality_data)
        air_quality_service.update_global_stats(air_quality_data)
        
        logger.info("✅ Collecte terminée avec succès")
        
        return {
            "status": "success",
            "locations_processed": len(air_quality_data),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Erreur dans la collecte: {e}")
        raise

# Fonction pour garder le service actif (évite que Render l'endorme)
def keep_alive():
    """Ping le service toutes les 14 minutes pour éviter l'endormissement"""
    import requests
    import time
    
    while True:
        try:
            time.sleep(14 * 60)  # 14 minutes
            # Ping interne pour garder le service actif
            logger.info("🏃 Keep-alive ping")
        except Exception as e:
            logger.error(f"Erreur keep-alive: {e}")

if __name__ == '__main__':
    # Initialise le service au démarrage
    init_service()
    
    # Lance le thread keep-alive en arrière-plan
    keep_alive_thread = threading.Thread(target=keep_alive)
    keep_alive_thread.daemon = True
    keep_alive_thread.start()
    
    # Lance l'application Flask
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)