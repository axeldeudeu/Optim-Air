#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri May 23 20:16:09 2025

@author: deudeu
"""

#!/usr/bin/env python3
"""
Script pour récupérer les données Air Quality de GCP et les envoyer vers Firebase
Conçu pour être exécuté sur Render avec un cron job toutes les 60 minutes
"""

import os
import json
import logging
import requests
from datetime import datetime, timezone
from typing import Dict, List, Optional
import firebase_admin
from firebase_admin import credentials, firestore
from google.oauth2 import service_account
from googleapiclient.discovery import build

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AirQualityService:
    def __init__(self):
        """Initialise les services GCP et Firebase"""
        self.gcp_service = None
        self.firestore_db = None
        self.setup_gcp_service()
        self.setup_firebase()
    
    def setup_gcp_service(self):
        """Configure le service GCP Air Quality API"""
        try:
            # Récupère les credentials GCP depuis les variables d'environnement
            gcp_credentials_json = os.getenv('AIzaSyAMT-I3hlf4oq0ITHxQq5iifAKO99A5fo0')
            if not gcp_credentials_json:
                raise ValueError("GCP_SERVICE_ACCOUNT_KEY non trouvée")
            
            credentials_info = json.loads(gcp_credentials_json)
            credentials_gcp = service_account.Credentials.from_service_account_info(
                credentials_info,
                scopes=['https://www.googleapis.com/auth/cloud-platform']
            )
            
            # Construit le service Air Quality API
            self.gcp_service = build('airquality', 'v1', credentials=credentials_gcp)
            logger.info("Service GCP Air Quality configuré avec succès")
            
        except Exception as e:
            logger.error(f"Erreur configuration GCP: {e}")
            raise
    
    def setup_firebase(self):
        """Configure Firebase Admin SDK"""
        try:
            # Récupère les credentials Firebase depuis les variables d'environnement
            firebase_credentials_json = os.getenv('d0f8ebdbd8a451b9df174e756b49b64cc0937eed')
            if not firebase_credentials_json:
                raise ValueError("FIREBASE_SERVICE_ACCOUNT_KEY non trouvée")
            
            credentials_info = json.loads(firebase_credentials_json)
            
            # Initialise Firebase si pas déjà fait
            if not firebase_admin._apps:
                cred = credentials.Certificate(credentials_info)
                firebase_admin.initialize_app(cred)
            
            self.firestore_db = firestore.client()
            logger.info("Firebase configuré avec succès")
            
        except Exception as e:
            logger.error(f"Erreur configuration Firebase: {e}")
            raise
    
    def get_air_quality_data(self, locations: List[Dict]) -> List[Dict]:
        """
        Récupère les données de qualité de l'air pour plusieurs locations
        
        Args:
            locations: Liste des locations [{"lat": float, "lng": float, "name": str}]
        
        Returns:
            Liste des données de qualité de l'air
        """
        air_quality_data = []
        
        for location in locations:
            try:
                # Prépare la requête pour l'API Air Quality
                request_body = {
                    "location": {
                        "latitude": location["lat"],
                        "longitude": location["lng"]
                    },
                    "extraComputations": [
                        "HEALTH_RECOMMENDATIONS",
                        "DOMINANT_POLLUTANT_CONCENTRATION",
                        "POLLUTANT_CONCENTRATION",
                        "LOCAL_AQI",
                        "POLLUTANT_ADDITIONAL_INFO"
                    ],
                    "languageCode": "fr"
                }
                
                # Appel à l'API Air Quality
                request = self.gcp_service.currentConditions().lookup(body=request_body)
                response = request.execute()
                
                # Structure les données pour Firebase
                processed_data = self.process_air_quality_response(response, location)
                air_quality_data.append(processed_data)
                
                logger.info(f"Données récupérées pour {location['name']}")
                
            except Exception as e:
                logger.error(f"Erreur récupération données pour {location['name']}: {e}")
                continue
        
        return air_quality_data
    
    def process_air_quality_response(self, response: Dict, location: Dict) -> Dict:
        """
        Traite la réponse de l'API Air Quality et la structure pour Firebase
        
        Args:
            response: Réponse de l'API Air Quality
            location: Informations de localisation
        
        Returns:
            Données structurées pour Firebase
        """
        try:
            # Extraction des données principales
            indexes = response.get('indexes', [])
            pollutants = response.get('pollutants', [])
            health_recommendations = response.get('healthRecommendations', {})
            
            # AQI principal (Universal AQI si disponible)
            main_aqi = None
            aqi_display_name = ""
            aqi_color = ""
            aqi_category = ""
            
            for index in indexes:
                if index.get('code') == 'uaqi':  # Universal AQI
                    main_aqi = index.get('aqi')
                    aqi_display_name = index.get('displayName', '')
                    aqi_color = index.get('color', {})
                    aqi_category = index.get('category', '')
                    break
            
            # Si pas d'Universal AQI, prendre le premier disponible
            if main_aqi is None and indexes:
                main_aqi = indexes[0].get('aqi')
                aqi_display_name = indexes[0].get('displayName', '')
                aqi_color = indexes[0].get('color', {})
                aqi_category = indexes[0].get('category', '')
            
            # Données des polluants
            pollutant_data = {}
            for pollutant in pollutants:
                code = pollutant.get('code', '')
                pollutant_data[code] = {
                    'displayName': pollutant.get('displayName', ''),
                    'fullName': pollutant.get('fullName', ''),
                    'concentration': pollutant.get('concentration', {}),
                    'additionalInfo': pollutant.get('additionalInfo', {})
                }
            
            # Structure finale pour Firebase
            firebase_data = {
                'location': {
                    'name': location['name'],
                    'latitude': location['lat'],
                    'longitude': location['lng']
                },
                'timestamp': datetime.now(timezone.utc).isoformat(),
                'lastUpdated': firestore.SERVER_TIMESTAMP,
                'aqi': {
                    'value': main_aqi,
                    'displayName': aqi_display_name,
                    'category': aqi_category,
                    'color': aqi_color
                },
                'indexes': indexes,
                'pollutants': pollutant_data,
                'healthRecommendations': {
                    'generalPopulation': health_recommendations.get('generalPopulation', ''),
                    'elderly': health_recommendations.get('elderly', ''),
                    'lungDiseasePopulation': health_recommendations.get('lungDiseasePopulation', ''),
                    'heartDiseasePopulation': health_recommendations.get('heartDiseasePopulation', ''),
                    'athletes': health_recommendations.get('athletes', ''),
                    'pregnantWomen': health_recommendations.get('pregnantWomen', ''),
                    'children': health_recommendations.get('children', '')
                }
            }
            
            return firebase_data
            
        except Exception as e:
            logger.error(f"Erreur traitement réponse API: {e}")
            raise
    
    def save_to_firebase(self, air_quality_data: List[Dict]):
        """
        Sauvegarde les données dans Firebase Firestore
        
        Args:
            air_quality_data: Liste des données de qualité de l'air
        """
        try:
            for data in air_quality_data:
                location_name = data['location']['name']
                
                # Sauvegarde dans la collection principale
                doc_ref = self.firestore_db.collection('air_quality').document(location_name)
                doc_ref.set(data, merge=True)
                
                # Sauvegarde historique (optionnel)
                history_ref = self.firestore_db.collection('air_quality_history').document()
                history_ref.set(data)
                
                logger.info(f"Données sauvegardées pour {location_name}")
                
        except Exception as e:
            logger.error(f"Erreur sauvegarde Firebase: {e}")
            raise
    
    def update_global_stats(self, air_quality_data: List[Dict]):
        """
        Met à jour les statistiques globales
        
        Args:
            air_quality_data: Liste des données de qualité de l'air
        """
        try:
            if not air_quality_data:
                return
            
            # Calcule des statistiques globales
            aqi_values = [data['aqi']['value'] for data in air_quality_data if data['aqi']['value']]
            
            if aqi_values:
                global_stats = {
                    'lastUpdate': firestore.SERVER_TIMESTAMP,
                    'totalLocations': len(air_quality_data),
                    'averageAQI': sum(aqi_values) / len(aqi_values),
                    'maxAQI': max(aqi_values),
                    'minAQI': min(aqi_values),
                    'locationsData': [
                        {
                            'name': data['location']['name'],
                            'aqi': data['aqi']['value'],
                            'category': data['aqi']['category']
                        }
                        for data in air_quality_data
                    ]
                }
                
                # Sauvegarde les stats globales
                stats_ref = self.firestore_db.collection('global_stats').document('air_quality')
                stats_ref.set(global_stats, merge=True)
                
                logger.info("Statistiques globales mises à jour")
                
        except Exception as e:
            logger.error(f"Erreur mise à jour stats globales: {e}")

def main():
    """Fonction principale du script"""
    try:
        logger.info("🚀 Début de la collecte des données Air Quality")
        
        # Initialise le service
        service = AirQualityService()
        
        # Liste des locations à surveiller (à adapter selon tes besoins)
        locations = [
            {"lat": 48.8566, "lng": 2.3522, "name": "Paris"},
            {"lat": 45.7640, "lng": 4.8357, "name": "Lyon"},
            {"lat": 43.2965, "lng": 5.3698, "name": "Marseille"},
            {"lat": 43.7102, "lng": 7.2620, "name": "Nice"},
            {"lat": 47.2184, "lng": -1.5536, "name": "Nantes"}
        ]
        
        # Tu peux aussi récupérer les locations depuis les variables d'environnement
        locations_env = os.getenv('LOCATIONS_JSON')
        if locations_env:
            try:
                locations = json.loads(locations_env)
                logger.info(f"Locations chargées depuis l'environnement: {len(locations)} locations")
            except json.JSONDecodeError:
                logger.warning("Erreur parsing LOCATIONS_JSON, utilisation des locations par défaut")
        
        # Récupère les données Air Quality
        logger.info(f"Récupération des données pour {len(locations)} locations")
        air_quality_data = service.get_air_quality_data(locations)
        
        if not air_quality_data:
            logger.warning("Aucune donnée récupérée")
            return
        
        # Sauvegarde dans Firebase
        logger.info(f"Sauvegarde de {len(air_quality_data)} enregistrements dans Firebase")
        service.save_to_firebase(air_quality_data)
        
        # Met à jour les statistiques globales
        service.update_global_stats(air_quality_data)
        
        logger.info("✅ Collecte des données terminée avec succès")
        
    except Exception as e:
        logger.error(f"❌ Erreur dans le script principal: {e}")
        raise

if __name__ == "__main__":
    main()