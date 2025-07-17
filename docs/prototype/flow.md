# Fast Track - Documentation complète du projet

## Vue d'ensemble du projet

### Présentation
**Fast Track** est un projet de simplification de la candidature aux marchés publics pour les très petites entreprises et petites et moyennes entreprises (TPE-PME), initié par le ministère de l'Économie et développé par la DINUM.

### Problématique
La complexité des procédures de candidature (formulaires DC1-DC2, service DUME, multiplicité des documents) décourage les TPE-PME de répondre aux appels d'offres publics, limitant leur accès à la commande publique.

### Objectif
Créer une solution de candidature réutilisable et interopérable qui transforme une démarche chronophage et complexe en un processus fluide et engageant, dans le cadre de la démarche "Dites-le-nous une fois".

### Impact visé
- Réduire les barrières à l'entrée pour les TPE-PME
- Augmenter leur participation aux marchés publics
- Garantir la conformité réglementaire et la confiance des acheteurs publics

## Considérations globales

### Architecture technique
- **Authentification inter-systèmes** : OAuth entre éditeurs et Fast Track
- **Intégration** : Via popup ou iFrame dans les plateformes éditeurs
- **Stockage** : Dossiers disponibles jusqu'à la date de fin du marché
- **Format des dossiers** : ZIP structuré contenant documents et preuves
- **Pas de limite de taille** en v1

### Principes de conception
- **Approche MVP** : Formulaire 100% manuel d'abord, automatisation progressive via API
- **Interopérabilité** : Solution agnostique vis-à-vis des éditeurs
- **Confidentialité** : Les candidats n'ont jamais accès aux dossiers déposés
- **Simplicité** : Pas d'espace utilisateur dédié, tout passe par les éditeurs

### Sécurité et conformité
- Vérification des éditeurs autorisés
- Validation côté serveur de toutes les données
- Protection contre les uploads malveillants
- Traçabilité complète des actions
- Horodatage officiel des candidatures

### Document généré par Fast Track
**Preuve de dépôt** (PDF unique) contenant :
- Horodatage officiel
- Liste des champs/documents demandés
- Indication "récupération automatique/manuelle" par champ
- Synthèse des informations saisies par le candidat

### Internationalisation
- MVP en français uniquement
- Architecture i18n préparée dès le départ
- Support multilingue prévu en phase ultérieure

## Parcours Acheteur

### Prérequis
- L'acheteur est authentifié sur sa plateforme éditeur habituelle
- L'éditeur est référencé et autorisé par Fast Track
- Pas de compte Fast Track nécessaire pour l'acheteur

### 1. Initialisation depuis l'éditeur
```
Contexte : Acheteur connecté sur sa plateforme habituelle
Action : Création d'un nouveau marché
└─> Saisie des informations (titre, description, dates...)
└─> Activation de l'option Fast Track
└─> Authentification OAuth avec Fast Track
```

### 2. Configuration dans Fast Track
```
Ouverture : Popup ou iFrame sécurisée

Page 1 - Type de marché :
├─> Sélection du type de marché
├─> Affichage des documents obligatoires (non modifiable)
└─> Continuer

Page 2 - Documents optionnels :
├─> Liste complète des documents additionnels
├─> Sélection selon les besoins
└─> Validation de la configuration
```

### 3. Publication du marché
```
Retour vers l'éditeur :
├─> ID unique Fast Track transmis
├─> Configuration confirmée
└─> Publication du marché avec candidature Fast Track activée
```

### 4. Réception des candidatures
```
Pour chaque candidature déposée :
├─> Notification Fast Track → Éditeur
├─> URL de téléchargement fournie
├─> Contenu du dossier ZIP :
│   ├─> Documents du/des candidat(s)
│   └─> Preuve de dépôt (PDF incluant la synthèse)
│
└─> Téléchargeable jusqu'à la date de fin du marché
```

### Spécificités acheteur
- **Multi-candidatures** : Plusieurs dossiers possibles par marché
- **Pas de tableau de bord** Fast Track, tout passe par l'éditeur
- **Notifications** : Via callback iFrame (v1), webhook prévu en v2

## Parcours Candidat

### Configuration
- **Identification** : SIRET uniquement, pas d'authentification
- **Documents** : PDF uniquement en v1
- **Langue** : Français uniquement (i18n préparé)
- **Pas de sauvegarde** intermédiaire en v1

### 1. Point d'entrée
```
Contexte : Candidat sur la plateforme d'un éditeur
Action : Consultation d'un marché public
└─> Bouton "Candidater via Fast Track"
└─> Ouverture dans nouvelle fenêtre/onglet
```

### 2. Identification
```
Page Fast Track - Écran SIRET :
├─> Champ unique : "Numéro SIRET de votre entreprise"
├─> Validation : Format 14 chiffres
├─> Si SIRET invalide → Message d'erreur
└─> Si SIRET valide → Chargement du formulaire
```

### 3. Formulaire de candidature
```
MVP - 100% manuel :
├─> Liste des champs texte à remplir
├─> Liste des documents à fournir
├─> Upload PDF pour chaque document requis
├─> Tous les champs sont obligatoires
└─> Bouton "Transmettre" actif quand tout est rempli

Future - Avec API :
├─> Récupération automatique en arrière-plan
├─> Indicateurs de statut (sans montrer les données) :
│   ✓ Document récupéré automatiquement
│   ✗ Récupération échouée → Upload manuel
└─> Fallback manuel si échec API
```

### 4. Transmission
```
Action : Clic sur "Transmettre ma candidature"
├─> Envoi des données
├─> Génération de l'attestation PDF
└─> Passage à l'écran final
```

### 5. Écran final - TÉLÉCHARGEMENT CRITIQUE
```
Éléments affichés :
├─> ⚠️ Message d'alerte prominent :
│   "ATTENTION : Téléchargez votre attestation maintenant.
│    C'est votre seule opportunité de la récupérer."
├─> Bouton principal : "📥 Télécharger mon attestation"
├─> Timer visible : 20 secondes
└─> Bouton "Terminer" (activé après 20s seulement)

Comportement :
├─> Téléchargement immédiat au clic
├─> Format : PDF avec horodatage
└─> Après "Terminer" → Retour impossible
```

### Spécificités candidat
- **Opacité des données API** : Le candidat ne voit jamais le contenu récupéré
- **Téléchargement unique** : Attestation disponible seulement en fin de parcours
- **Entreprises étrangères** : Non supportées (SIRET requis)

### Intégration et documentation

La rédaction de la documentation technique pour les éditeurs est à prévoir.

L'ensemble du parcours étant en place, il est désormais possible pour les éditeurs de 
démarrer l'intégration de la solution et permet aux équipes fast track d'avancer de facon 100% indépendantes.
Des ajustements seront à prévoir selon les dicussions avec les éditeurs.

## Évolutions futures (post-MVP)

### Phase 2 - Automatisation
- Intégration progressive des API (INSEE, URSSAF, etc.)
- Récupération automatique des documents
- Indicateurs de succès/échec par document

### Améliorations envisagées
- **Candidatures groupées** : Plusieurs entreprises par candidature
- **Sauvegarde de progression** : Reprise de candidature en cours
- **Formats additionnels** : Au-delà du PDF
- **Email de confirmation** : Envoi optionnel de l'attestation
- **Support multilingue** : Entreprises européennes
- **Analytics** : Tracking du parcours et des performances
- **Gestion des lots** : Réponse à plusieurs lots d'un marché
- **Espace de suivi acheteur** : Tableau de bord dédié

### Points en suspens
- Modification/retrait de candidature avant date limite
- Récupération d'attestation après coup
- Gestion des erreurs techniques
- Limite de taille des documents
- Support des entreprises sans SIRET

## Contacts et gouvernance

- **Pilotage** : Direction des Affaires juridiques de Bercy
- **Réalisation** : DINUM
- **Investigation** : Binôme Product Manager / UX Designer
