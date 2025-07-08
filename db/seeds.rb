# frozen_string_literal: true

# Fast Track - Document Seeds
# Creates test documents for market configuration testing

puts "🚀 Seeding Fast Track documents..."

# Clear existing documents
Document.delete_all

# === DOCUMENTS OBLIGATOIRES ===
# Ces documents sont requis pour tous les types de marchés

mandatory_docs = [
  {
    nom: "SIRET de l'entreprise",
    description: "Extrait SIRET de moins de 3 mois prouvant l'existence légale de l'entreprise",
    categorie: "administratif",
    obligatoire: true,
    type_marche: nil # Applicable à tous les types
  },
  {
    nom: "Déclaration sur l'honneur DUME",
    description: "Document unique de marché européen attestant que l'entreprise respecte les critères d'exclusion",
    categorie: "administratif", 
    obligatoire: true,
    type_marche: nil
  },
  {
    nom: "Attestation d'assurance responsabilité civile",
    description: "Justificatif d'assurance couvrant la responsabilité civile professionnelle en cours de validité",
    categorie: "administratif",
    obligatoire: true,
    type_marche: nil
  }
]

# === DOCUMENTS SPÉCIFIQUES FOURNITURES ===
supplies_docs = [
  {
    nom: "Catalogue produits",
    description: "Présentation détaillée des produits proposés avec spécifications techniques",
    categorie: "technique",
    obligatoire: false,
    type_marche: "supplies"
  },
  {
    nom: "Certificats de conformité CE",
    description: "Attestations de conformité aux normes européennes pour les produits concernés",
    categorie: "technique",
    obligatoire: false,
    type_marche: "supplies"
  },
  {
    nom: "Liste des références clients",
    description: "Principales références de fournitures similaires sur les 3 dernières années",
    categorie: "technique",
    obligatoire: false,
    type_marche: "supplies"
  },
  {
    nom: "Conditions générales de vente",
    description: "CGV applicables aux fournitures proposées",
    categorie: "juridique",
    obligatoire: false,
    type_marche: "supplies"
  }
]

# === DOCUMENTS SPÉCIFIQUES SERVICES ===
services_docs = [
  {
    nom: "Méthodologie d'intervention",
    description: "Présentation détaillée de l'approche méthodologique pour la réalisation de la prestation",
    categorie: "technique",
    obligatoire: false,
    type_marche: "services"
  },
  {
    nom: "CV des intervenants",
    description: "Curriculum vitae détaillés des personnes qui seront affectées à la mission",
    categorie: "technique",
    obligatoire: false,
    type_marche: "services"
  },
  {
    nom: "Références de prestations similaires",
    description: "Liste des prestations de services similaires réalisées sur les 3 dernières années",
    categorie: "technique",
    obligatoire: false,
    type_marche: "services"
  },
  {
    nom: "Moyens humains et techniques",
    description: "Description des ressources humaines et matérielles mobilisables pour la prestation",
    categorie: "technique",
    obligatoire: false,
    type_marche: "services"
  },
  {
    nom: "Planning prévisionnel",
    description: "Échéancier détaillé de réalisation de la prestation",
    categorie: "technique",
    obligatoire: false,
    type_marche: "services"
  }
]

# === DOCUMENTS SPÉCIFIQUES TRAVAUX ===
works_docs = [
  {
    nom: "Attestation de qualification professionnelle",
    description: "Qualification Qualibat, FNTP ou équivalent selon les corps de métier",
    categorie: "technique",
    obligatoire: true,
    type_marche: "works"
  },
  {
    nom: "Attestation d'assurance décennale",
    description: "Garantie décennale en cours de validité couvrant les travaux proposés",
    categorie: "administratif",
    obligatoire: true,
    type_marche: "works"
  },
  {
    nom: "Références de chantiers similaires",
    description: "Liste des chantiers de nature et d'importance similaires réalisés sur les 5 dernières années",
    categorie: "technique",
    obligatoire: false,
    type_marche: "works"
  },
  {
    nom: "Moyens techniques et humains",
    description: "Description du matériel et des équipes qui seront affectés au chantier",
    categorie: "technique",
    obligatoire: false,
    type_marche: "works"
  },
  {
    nom: "Planning de réalisation",
    description: "Planning détaillé d'exécution des travaux avec jalons intermédiaires",
    categorie: "technique",
    obligatoire: false,
    type_marche: "works"
  },
  {
    nom: "Plan Général de Coordination",
    description: "Plan de coordination en matière de sécurité et de protection de la santé (si applicable)",
    categorie: "technique",
    obligatoire: false,
    type_marche: "works"
  }
]

# === DOCUMENTS FINANCIERS OPTIONNELS ===
financial_docs = [
  {
    nom: "Liasses fiscales",
    description: "Comptes annuels des 3 derniers exercices clos (bilan, compte de résultat, annexes)",
    categorie: "financier",
    obligatoire: false,
    type_marche: nil
  },
  {
    nom: "Chiffre d'affaires par secteur",
    description: "Répartition du CA sur les 3 dernières années par secteur d'activité",
    categorie: "financier",
    obligatoire: false,
    type_marche: nil
  },
  {
    nom: "Attestation bancaire",
    description: "Attestation de capacité financière délivrée par l'établissement bancaire",
    categorie: "financier",
    obligatoire: false,
    type_marche: nil
  },
  {
    nom: "Déclaration fiscale et sociale",
    description: "Attestations de régularité fiscale et sociale (URSSAF, impôts)",
    categorie: "administratif",
    obligatoire: false,
    type_marche: nil
  }
]

# Combine all documents
all_documents = mandatory_docs + supplies_docs + services_docs + works_docs + financial_docs

# Create documents
created_count = 0
all_documents.each do |doc_data|
  doc = Document.create!(doc_data)
  created_count += 1
  puts "✅ Created: #{doc.nom} (#{doc.categorie}#{doc.type_marche ? " - #{doc.type_marche}" : ""})#{doc.obligatoire? ? " [OBLIGATOIRE]" : ""}"
end

puts "\n📊 Documents créés avec succès :"
puts "   🟢 Obligatoires (tous marchés): #{Document.mandatory.where(type_marche: nil).count}"
puts "   🔵 Fournitures: #{Document.where(type_marche: 'supplies').count}"
puts "   🟡 Services: #{Document.where(type_marche: 'services').count}"
puts "   🟠 Travaux: #{Document.where(type_marche: 'works').count}"
puts "   💰 Financiers (optionnels): #{Document.where(categorie: 'financier').count}"
puts "   📋 TOTAL: #{created_count} documents"

puts "\n🎯 Fast Track est maintenant prêt pour les tests !"
puts "   - Les éditeurs peuvent configurer des marchés avec des documents réalistes"
puts "   - Chaque type de marché a ses documents spécifiques"
puts "   - Les documents obligatoires sont automatiquement inclus"

# === ÉDITEUR DE DÉVELOPPEMENT ===
puts "\n🔧 Configuration éditeur de développement..."

dev_editor = Editor.find_or_create_by(name: "Fast Track Dev Editor") do |editor|
  editor.client_id = SecureRandom.hex(16)
  editor.client_secret = SecureRandom.hex(32)
  editor.callback_url = "http://localhost:4000/auth/fasttrack/callback"
  editor.authorized = true
  editor.active = true
end

# Sync with Doorkeeper
dev_editor.sync_to_doorkeeper!

puts "✅ Éditeur de développement configuré :"
puts "   📝 Nom: #{dev_editor.name}"
puts "   🆔 Client ID: #{dev_editor.client_id}"
puts "   🔐 Client Secret: #{dev_editor.client_secret}"
puts "   🌐 Callback URL: #{dev_editor.callback_url}"

puts "\n🎉 Setup Fast Track terminé !"
puts "   📊 #{Document.count} documents disponibles"
puts "   👥 #{Editor.count} éditeur(s) configuré(s)"
puts "   🏠 Page d'accueil: http://localhost:3000"
puts "   🔧 Admin éditeurs: http://localhost:3000/admin/editors"
