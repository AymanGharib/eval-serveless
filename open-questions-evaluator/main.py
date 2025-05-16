from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import google.generativeai as genai
import json
import re
from typing import Optional
from fastapi.middleware.cors import CORSMiddleware

# Configuration de l'API
app = FastAPI(title="API Feedback Pédagogique",
            description="API pour générer des feedbacks pédagogiques automatisés")

# Configuration CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # À modifier en production pour plus de sécurité
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration de Gemini (à remplacer par votre clé API)
GOOGLE_API_KEY = "AIzaSyDAS9yKZDgJGn_vcAyficnAzA3JsMMc5gg"
genai.configure(api_key=GOOGLE_API_KEY)
model = genai.GenerativeModel("gemini-1.5-flash")

# Modèles de données
class FeedbackRequest(BaseModel):
    reponse: str
    question: str
    niveau: str
    difficulte: str

class FeedbackResponse(BaseModel):
    feedback: str
    note: float

def generer_feedback(reponse, question, niveau, difficulte):
    prompt = f"""
Tu es un enseignant marocain bienveillant. Tu donnes un feedback pédagogique à un élève du niveau {niveau}, avec une difficulté de question : {difficulte}.

Voici la question posée à l'élève : "{question}"
Et voici sa réponse : "{reponse}"

Tu dois adapter ton jugement selon le niveau de l'élève :
- Si l'élève est jeune (CP, CE1…), sois plus indulgent.
- Si l'élève est plus avancé (CM1, CM2…), sois plus exigeant.
Note sur 5, selon cette grille :
- 5 : Réponse très bien formulée, complète, adaptée au niveau, sans faute ou avec une très légère. L'élève montre une bonne compréhension.
- 4 : Bonne réponse, mais il manque un petit élément de précision ou la formulation est un peu maladroite. Quelques fautes mineures possibles.
- 3 : Réponse partiellement correcte, mais incomplète, ou formulation très maladroite. Il peut y avoir plusieurs erreurs de grammaire ou d'orthographe.
- 2 : Réponse compréhensible mais très insuffisante, vague, ou très mal formulée. Beaucoup d'erreurs. Manque d'effort ou de clarté.
- 1 : Réponse hors sujet, très pauvre, ou incompréhensible. Ne montre pas de compréhension de la question. Mauvaise grammaire ou vocabulaire.

Répondre UNIQUEMENT au format JSON suivant, sans aucun texte avant ou après les accolades :
{{"feedback": "phrase courte", "note": nombre}}
"""
    try:
        response = model.generate_content(prompt)
        
        # Extraire uniquement le JSON de la réponse
        json_match = re.search(r'\{.*\}', response.text, re.DOTALL)
        if not json_match:
            return {"feedback": "Format de réponse invalide", "note": 0}
            
        json_str = json_match.group(0)
        
        # Nettoyer la chaîne JSON
        json_str = json_str.strip()
        json_str = re.sub(r'[\n\r\t]', '', json_str)
        
        # Parser le JSON
        result = json.loads(json_str)
        
        # Valider le format
        if not isinstance(result, dict):
            return {"feedback": "Format de réponse invalide", "note": 0}
        if "feedback" not in result or "note" not in result:
            return {"feedback": "Réponse incomplète", "note": 0}
        if not isinstance(result["note"], (int, float)) or not isinstance(result["feedback"], str):
            return {"feedback": "Types de données invalides", "note": 0}
        if not (0 <= result["note"] <= 5):
            return {"feedback": "Note hors limites", "note": 0}
            
        return result
        
    except Exception as e:
        return {
            "feedback": f"Erreur technique : {str(e)[:100]}", 
            "note": 0
        }

# Routes API
@app.get("/")
async def root():
    return {"message": "Bienvenue sur l'API de feedback pédagogique"}

@app.post("/feedback", response_model=FeedbackResponse)
async def obtenir_feedback(request: FeedbackRequest):
    try:
        resultat = generer_feedback(
            request.reponse,
            request.question,
            request.niveau,
            request.difficulte
        )
        return resultat
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Endpoint pour vérifier la santé de l'API
@app.get("/health")
async def health_check():
    return {"status": "healthy"}