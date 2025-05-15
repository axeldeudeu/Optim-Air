Optim'Air
API pour la Qualité de l'Air des Villes
Cette API permet de gérer et consulter des données de qualité d'air pour différentes villes, en intégrant l'API Google Air Quality.
Déploiement sur Render
1. Prérequis

Un compte Render
Un compte Firebase avec une base Firestore
Une clé API Google Cloud Platform avec accès à l'API Air Quality

2. Configuration Render

Créez un nouveau Web Service sur Render
Connectez votre dépôt Git contenant le code
Configurez les variables d'environnement suivantes:

GCP_API_KEY: Votre clé API Google Cloud Platform
FIREBASE_CREDENTIALS_PATH: Chemin vers votre fichier de credentials Firebase (par défaut: "firebase-key.json")


Créez un fichier firebase-key.json dans les secrets de Render avec le contenu de votre fichier de credentials Firebase

3. Structure du projet
.
├── main.py
├── requirements.txt
└── firebase-key.json (secret)
Routes API
Vérification d'état
GET /health
Vérifie que l'API est opérationnelle.
Mise à jour d'une ville
POST /maj_ville
Ajoute ou met à jour les données d'une ville, y compris la qualité de l'air.
Exemple de corps de requête:
json{
  "nom": "Paris",
  "code": "paris",
  "lat": 48.856614,
  "lon": 2.3522219,
  "source": "manuel",
  "monuments": ["Tour Eiffel", "Notre Dame", "Louvre"],
  "shopping": ["Champs-Élysées", "Galeries Lafayette"],
  "parcs_attractions": ["Disneyland Paris"]
}
Mise à jour par CSV
POST /maj_csv
Importe des données à partir d'un fichier CSV.
Format CSV requis:
nom,code,lat,lon,source,monuments,shopping,parcs
Paris,paris,48.856614,2.3522219,csv,Tour Eiffel|Notre Dame|Louvre,Champs-Élysées|Galeries Lafayette,Disneyland Paris
Liste des villes
GET /villes
Récupère la liste de toutes les villes avec leur indice de qualité d'air.
Détails d'une ville
GET /ville/<code_ville>
Récupère les détails complets d'une ville spécifique.
Format des données
Structure des documents Firestore
json{
  "city": "Paris",
  "country": "France",
  "country_code": "FR",
  "source": "API",
  "coordinates": {
    "latitude": 48.856614,
    "longitude": 2.3522219
  },
  "timestamp": "2025-05-15T12:34:56.789Z",
  "monuments": ["Tour Eiffel", "Notre Dame", "Louvre"],
  "shopping": ["Champs-Élysées", "Galeries Lafayette"],
  "parcs_attractions": ["Disneyland Paris"],
  "aqi_score": 75,
  "aqi_category": "Moyen",
  "pollutants": {
    "pm25": 12.3,
    "pm10": 24.5,
    "no2": 45.6
  }
