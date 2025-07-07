# Fast Track - Liste des tâches de réalisation

## 🌐 Partie Globale

### 1. Infrastructure et Architecture

#### 1.1 Base de données
- [ ] Concevoir le schéma de base de données complet
- [ ] Définir les tables principales (marchés, candidatures, documents, éditeurs)
- [ ] Planifier la stratégie de partitionnement pour les gros volumes
- [ ] Mettre en place les index nécessaires
- [ ] Configurer les backups automatiques

#### 1.2 Sécurité
- [ ] Implémenter l'authentification OAuth2 pour les éditeurs
- [ ] Mettre en place le système de tokens et refresh tokens
- [ ] Configurer les CSP (Content Security Policy)
- [ ] Implémenter la protection CSRF
- [ ] Mettre en place le rate limiting
- [ ] Configurer les règles CORS pour les iFrames
- [ ] Implémenter la validation côté serveur de tous les inputs
- [ ] Préparer l'architecture pour un futur antivirus (point d'injection)

#### 1.3 Stockage des fichiers
- [ ] Implémenter le stockage local Rails (Active Storage)
- [ ] Créer le système de génération de ZIP
- [ ] Mettre en place la gestion des URLs temporaires sécurisées

### 2. Services et Intégrations

#### 2.1 Génération PDF
- [ ] Choisir la librairie de génération PDF (Prawn, WickedPDF, etc.)
- [ ] Designer les templates de preuves de dépôt
- [ ] Implémenter la génération avec données dynamiques
- [ ] Ajouter les éléments de sécurité (watermark, QR code, etc.)
- [ ] Optimiser les performances de génération
- [ ] Implémenter l'horodatage interne (DateTime) dans les PDF

#### 2.2 Système de notifications
- [ ] Implémenter le système de callbacks iFrame
- [ ] Préparer l'architecture pour les webhooks (v2)
- [ ] Créer le système de retry en cas d'échec
- [ ] Mettre en place le monitoring des notifications

### 3. Gestion des éditeurs

#### 3.1 Référentiel éditeurs
- [ ] Créer l'interface d'administration des éditeurs
- [ ] Implémenter le système de validation/autorisation
- [ ] Gérer les clés API et secrets OAuth
- [ ] Créer le système de révocation d'accès
- [ ] Mettre en place les logs d'audit

#### 3.2 Documentation technique
- [ ] Rédiger la documentation d'intégration OAuth
- [ ] Créer les exemples de code pour les éditeurs
- [ ] Documenter les endpoints API
- [ ] Créer un environnement de test (sandbox)
- [ ] Rédiger les guides de dépannage

### 4. Internationalisation (i18n)

#### 4.1 Architecture i18n
- [ ] Configurer Rails i18n
- [ ] Structurer les fichiers de traduction
- [ ] Définir la stratégie de gestion des locales
- [ ] Préparer le système de détection de langue
- [ ] Créer les helpers de traduction

#### 4.2 Contenu initial
- [ ] Créer tous les textes en français
- [ ] Identifier les éléments non-textuels à adapter (dates, nombres, etc.)
- [ ] Préparer la structure pour les futures traductions

### 5. Logging et Traçabilité

#### 5.1 Logging
- [ ] Configurer la stratégie de logs structurés
- [ ] Définir les niveaux de logs appropriés
- [ ] Implémenter la traçabilité complète des actions
- [ ] Créer les logs spécifiques pour l'audit

### 6. Tests et Qualité

#### 6.1 Stratégie de tests
- [ ] Mettre en place les tests unitaires (RSpec)
- [ ] Configurer les tests d'intégration
- [ ] Implémenter les tests de bout en bout
- [ ] Configurer la couverture de code minimale

#### 6.2 Qualité de code
- [ ] Mettre en place les hooks pre-commit
- [ ] Configurer les revues de code obligatoires
- [ ] Implémenter l'analyse de sécurité du code

### 7. Configuration et paramétrage

#### 7.1 Configuration application
- [ ] Mettre en place les variables d'environnement
- [ ] Créer les fichiers de configuration (credentials Rails)
- [ ] Configurer les timeouts et limites
- [ ] Paramétrer les durées de validité des tokens

#### 7.2 Gestion des erreurs
- [ ] Créer les pages d'erreur personnalisées
- [ ] Implémenter la gestion centralisée des exceptions
- [ ] Mettre en place les notifications d'erreurs critiques

---

## 📋 Flow Acheteur

### 1. Authentification et autorisation

#### 1.1 API OAuth avec les éditeurs
- [ ] Créer le controller API OAuth pour les éditeurs
- [ ] Implémenter les endpoints OAuth2 (authorize, token)
- [ ] Gérer les différents scopes selon les éditeurs
- [ ] Implémenter la validation des états OAuth
- [ ] Gérer les erreurs et les réponses JSON
- [ ] Documenter les endpoints OAuth

#### 1.2 Session et contexte
- [ ] Gérer la session acheteur via token éditeur
- [ ] Stocker le contexte du marché en cours
- [ ] Implémenter la validation des permissions
- [ ] Gérer l'expiration et le refresh des tokens

### 2. Configuration du marché

#### 2.1 Interface de configuration
- [ ] Créer le controller de configuration des marchés
- [ ] Développer la page de sélection du type de marché
- [ ] Implémenter la logique des documents obligatoires par type
- [ ] Créer la page de sélection des documents optionnels
- [ ] Gérer la navigation entre les étapes

#### 2.2 Gestion des documents
- [ ] Créer le modèle de documents disponibles
- [ ] Implémenter la catégorisation (obligatoires/optionnels)
- [ ] Créer les seeds automatiques temporaires
- [ ] Gérer les règles métier par type de marché
- [ ] Implémenter la validation de la configuration

#### 2.3 Communication avec l'éditeur
- [ ] Créer le système de callback vers l'éditeur
- [ ] Implémenter l'envoi de l'ID unique Fast Track
- [ ] Gérer les messages via postMessage (iFrame)
- [ ] Créer la confirmation de configuration
- [ ] Gérer les cas d'erreur de communication

### 3. Création et stockage du marché

#### 3.1 Modèle de données
- [ ] Créer le modèle Marché avec tous les attributs
- [ ] Implémenter les associations avec les éditeurs
- [ ] Créer la relation avec les documents requis
- [ ] Gérer l'ID unique et les références externes
- [ ] Implémenter les validations métier

#### 3.2 Persistance
- [ ] Créer le service de création de marché
- [ ] Implémenter la transaction de sauvegarde
- [ ] Gérer la génération d'identifiants uniques
- [ ] Créer les indexes pour les recherches
- [ ] Implémenter l'archivage des configurations

### 4. Réception des candidatures

#### 4.1 Notifications via iFrame
- [ ] Implémenter le callback postMessage en fin de candidature
- [ ] Transmettre l'ID de candidature à l'éditeur
- [ ] Gérer les erreurs de transmission
- [ ] Créer les logs de notification
- [ ] Préparer l'architecture pour webhooks (v2)

#### 4.2 Accès aux dossiers
- [ ] Créer les URLs temporaires sécurisées
- [ ] Implémenter la vérification des permissions
- [ ] Gérer la durée de validité des liens
- [ ] Créer le controller de téléchargement
- [ ] Implémenter les logs d'accès

#### 4.3 Format des dossiers
- [ ] Structurer le contenu du ZIP
- [ ] Organiser les documents par candidat
- [ ] Inclure la preuve de dépôt dans le ZIP
- [ ] Gérer les métadonnées du dossier
- [ ] Optimiser la compression

### 5. Gestion des erreurs

#### 5.1 Erreurs spécifiques acheteur
- [ ] Créer les vues d'erreur pour l'iFrame
- [ ] Implémenter les messages d'erreur contextuels
- [ ] Gérer les cas de timeout
- [ ] Créer les logs d'erreurs détaillés
- [ ] Gérer la communication d'erreur vers l'éditeur

### 6. Intégration iFrame/Popup

#### 6.1 Sécurité iFrame
- [ ] Implémenter les headers de sécurité
- [ ] Configurer X-Frame-Options correctement
- [ ] Gérer la liste blanche des domaines autorisés
- [ ] Implémenter la validation des origines
- [ ] Créer les protections anti-clickjacking

#### 6.2 Communication cross-domain
- [ ] Implémenter l'API postMessage
- [ ] Créer le protocole de communication
- [ ] Gérer les événements (resize, close, etc.)
- [ ] Implémenter la gestion d'erreurs
- [ ] Créer la documentation du protocole

### 7. Tests spécifiques acheteur

#### 7.1 Tests d'intégration
- [ ] Tester le flow OAuth API complet
- [ ] Tester la configuration de marché
- [ ] Tester le callback iFrame de fin de candidature
- [ ] Tester le téléchargement des dossiers
- [ ] Tester les cas d'erreur

#### 7.2 Tests de sécurité
- [ ] Tester les permissions et autorisations
- [ ] Tester la validation des tokens
- [ ] Tester les protections iFrame
- [ ] Tester l'isolation des données
- [ ] Tester les tentatives de fraude

---

## 👤 Flow Candidat

### 1. Point d'entrée et navigation

#### 1.1 Accès depuis l'éditeur
- [ ] Créer le controller de candidature
- [ ] Implémenter la validation du marché (ID, dates limites)
- [ ] Gérer l'ouverture dans nouvelle fenêtre/onglet
- [ ] Vérifier que le marché accepte Fast Track
- [ ] Créer la page d'erreur si marché invalide/expiré

#### 1.2 Navigation et état
- [ ] Implémenter la gestion de session candidat (stateless)
- [ ] Créer le système de navigation entre étapes
- [ ] Gérer le blocage du retour arrière après soumission
- [ ] Implémenter les timeouts de session
- [ ] Créer les redirections en cas d'erreur

### 2. Identification SIRET

#### 2.1 Interface SIRET
- [ ] Créer la page de saisie SIRET
- [ ] Implémenter le champ avec masque de saisie
- [ ] Créer la validation format (14 chiffres)
- [ ] Ajouter les messages d'erreur explicites

#### 2.2 Validation SIRET
- [ ] Implémenter la validation côté serveur
- [ ] Créer le service de vérification format
- [ ] Implémenter le retour de fausses données entreprise
- [ ] Préparer l'architecture pour future API INSEE
- [ ] Gérer les cas d'erreur
- [ ] Logger les tentatives de validation

### 3. Formulaire de candidature

#### 3.1 Génération dynamique
- [ ] Créer le générateur de formulaire selon config marché
- [ ] Implémenter l'affichage des champs requis
- [ ] Créer les composants de formulaire réutilisables
- [ ] Gérer l'ordre d'affichage des champs
- [ ] Implémenter la validation temps réel

#### 3.2 Upload de documents
- [ ] Créer le composant d'upload PDF simple
- [ ] Implémenter la validation des fichiers (type, taille)
- [ ] Gérer le remplacement de document
- [ ] Afficher le nom du fichier uploadé
- [ ] Créer les messages d'erreur d'upload

#### 3.3 Gestion des données
- [ ] Créer le modèle Candidature
- [ ] Implémenter le stockage temporaire des fichiers
- [ ] Gérer la validation côté serveur
- [ ] Créer les associations avec le marché
- [ ] Implémenter le nettoyage des données orphelines

#### 3.4 MVP sans API
- [ ] Afficher tous les champs en mode manuel
- [ ] Rendre tous les champs obligatoires
- [ ] Désactiver le bouton tant que incomplet
- [ ] Créer les tooltips d'aide
- [ ] Gérer les messages d'erreur inline

### 4. Transmission de la candidature

#### 4.1 Soumission
- [ ] Créer le service de soumission
- [ ] Implémenter la transaction complète
- [ ] Générer l'identifiant unique de candidature
- [ ] Créer le ZIP avec tous les documents
- [ ] Déclencher la génération PDF de l'attestation

#### 4.2 Génération de l'attestation
- [ ] Créer le template PDF de l'attestation
- [ ] Inclure toutes les informations saisies
- [ ] Ajouter l'horodatage et l'ID unique
- [ ] Marquer les champs "récupération manuelle"
- [ ] Structurer le PDF de manière claire

#### 4.3 Stockage final
- [ ] Sauvegarder la candidature complète
- [ ] Archiver le ZIP généré
- [ ] Stocker l'attestation PDF
- [ ] Créer les métadonnées de traçabilité
- [ ] Implémenter la liaison avec le marché

### 5. Écran final et téléchargement

#### 5.1 Page de confirmation
- [ ] Créer la page finale avec message d'alerte
- [ ] Implémenter le bouton de téléchargement prominent
- [ ] Créer le timer visuel (20 secondes)
- [ ] Bloquer le bouton "Terminer" pendant 20s
- [ ] Ajouter les animations d'attention

#### 5.2 Téléchargement de l'attestation
- [ ] Implémenter le téléchargement immédiat
- [ ] Gérer les erreurs de téléchargement
- [ ] Créer le nom de fichier explicite
- [ ] Logger le téléchargement effectué
- [ ] Gérer le cas de blocage navigateur

#### 5.3 Finalisation
- [ ] Implémenter le bouton "Terminer"
- [ ] Créer la notification à l'éditeur (postMessage)
- [ ] Nettoyer la session candidat
- [ ] Bloquer tout retour arrière
- [ ] Fermer la fenêtre ou rediriger

### 6. Gestion des erreurs candidat

#### 6.1 Erreurs utilisateur
- [ ] Créer les messages d'erreur contextuels
- [ ] Implémenter la récupération gracieuse
- [ ] Gérer les timeouts de session
- [ ] Créer les pages d'erreur dédiées
- [ ] Logger les erreurs pour analyse

#### 6.2 Erreurs techniques
- [ ] Gérer les échecs d'upload
- [ ] Implémenter les retry automatiques
- [ ] Créer les fallbacks en cas d'erreur PDF
- [ ] Gérer la perte de connexion
- [ ] Implémenter la sauvegarde d'urgence

### 7. Optimisations UX

#### 7.1 Performance
- [ ] Optimiser le chargement des pages
- [ ] Implémenter le lazy loading des composants
- [ ] Créer les indicateurs de progression
- [ ] Optimiser la taille des uploads
- [ ] Minimiser les temps d'attente

#### 7.2 Accessibilité minimale
- [ ] Assurer la navigation au clavier
- [ ] Créer les labels explicites
- [ ] Gérer le focus correctement
- [ ] Implémenter les messages d'erreur accessibles
- [ ] Tester avec un lecteur d'écran

### 8. Tests spécifiques candidat

#### 8.1 Tests fonctionnels
- [ ] Tester le parcours complet
- [ ] Tester la validation SIRET
- [ ] Tester l'upload de documents
- [ ] Tester la génération PDF
- [ ] Tester le téléchargement final

#### 8.2 Tests de robustesse
- [ ] Tester les interruptions de parcours
- [ ] Tester les uploads volumineux
- [ ] Tester les navigateurs différents
- [ ] Tester la perte de connexion
- [ ] Tester les cas limites
