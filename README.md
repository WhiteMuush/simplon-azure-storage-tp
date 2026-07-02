# TP Pratique — Module 3 : Stockage Azure avec az CLI

**Durée estimée : 30-40 min**
**Prérequis : az CLI installé, connecté à Azure (`az login`), groupe de ressources existant**
**Niveau : Débutant — avoir fait le TP portail Module 3**

---

## 🎯 Scénario

L'API d'**AzureTech** est en production. Votre équipe a deux besoins :

1. **Stocker les logs de l'API** — fichiers privés, accessibles uniquement par les développeurs authentifiés
2. **Exposer un fichier de configuration** — fichier public que les clients de l'API téléchargent au démarrage

Vous allez reproduire avec `az CLI` exactement ce que vous avez fait dans le portail — mais cette fois en une suite de commandes reproductibles et automatisables.

> 💡 **Pourquoi CLI plutôt que portail ?**
> Les commandes CLI peuvent être intégrées dans un script `provision.sh`, versionnées dans Git, et exécutées automatiquement dans une pipeline GitHub Actions. Le portail ne laisse aucune trace, le CLI laisse du code.

---

## Variables — à définir avant de commencer

Toutes les commandes suivantes utilisent ces variables. Définissez-les une seule fois dans votre terminal :

```bash
# Votre identifiant — remplacez par votre prénom-nom (minuscules, sans espaces)
export OWNER="prenom-nom"

# Nom de votre resource group (fourni par le formateur)
export RG="rg-${OWNER}"

# Région Azure
export LOCATION="francecentral"

# Tags appliqués à toutes les ressources (pour le cleanup du vendredi)
export TAGS="managed_by=cli environment=tp owner=${OWNER}"

# Nom du storage account (3-24 chars, minuscules + chiffres uniquement)
export SA_NAME="st${OWNER//-/}cli"

echo "OWNER        = $OWNER"
echo "RG           = $RG"
echo "SA_NAME      = $SA_NAME"
```

> ⚠️ Si vous fermez votre terminal, vous devrez redéfinir ces variables.

---

## Partie 1 — Créer le compte de stockage (5 min)

### 1.1 Vérifier que votre resource group existe

```bash
az group show --name "$RG" --output table
```

Résultat attendu :
```
Name              Location       Status
----------------  -------------  ---------
rg-prenom-nom     francecentral  Succeeded
```

> ❌ Si vous obtenez une erreur `ResourceGroupNotFound`, contactez le formateur.

---

### 1.2 Créer le compte de stockage

> 🧠 **Pourquoi ?** Un **Storage Account** est le conteneur de base pour toutes les données Azure (blobs, fichiers, files d'attente, tables). On le crée en premier car les conteneurs et blobs vivent à l'intérieur. Les paramètres `--sku` et `--kind` déterminent la redondance et les fonctionnalités disponibles.

```bash
az storage account create \
  --name           "$SA_NAME" \
  --resource-group "$RG" \
  --location       "$LOCATION" \
  --sku            Standard_LRS \
  --kind           StorageV2 \
  --allow-blob-public-access true \
  --tags           $TAGS
```

**Décryptage des paramètres :**
- `--sku Standard_LRS` : redondance locale (3 copies dans le même datacenter)
- `--kind StorageV2` : version moderne, supporte Blob, File, Queue, Table
- `--allow-blob-public-access true` : nécessaire pour créer un conteneur public (Partie 3)

**Vérifier la création :**
```bash
az storage account show \
  --name           "$SA_NAME" \
  --resource-group "$RG" \
  --query          "{nom:name, region:location, sku:sku.name, statut:provisioningState}" \
  --output         table
```

> ❓ **Question :** Vous avez choisi `Standard_LRS`. Si l'API d'AzureTech doit rester disponible même en cas de panne d'un datacenter Azure entier, quelle option choisiriez-vous ? Tapez la commande suivante et observez les options disponibles :
> ```bash
> az storage account list-skus --location "$LOCATION" --query "[].name" --output table
> # Options : Standard_LRS, Standard_ZRS, Standard_GRS, Standard_GZRS, Premium_LRS
> ```

<details>
<summary>💡 Correction</summary>

**Standard_GRS** (Geo-Redundant Storage) ou **Standard_GZRS** (Geo-Zone-Redundant Storage) selon le niveau de protection souhaité.

| SKU | Protection | Cas d'usage |
|-----|-----------|-------------|
| `Standard_LRS` | 3 copies, même datacenter | Dev/test, données reconstructibles |
| `Standard_ZRS` | 3 zones d'une même région | Production standard |
| `Standard_GRS` | LRS + copie dans une autre région Azure | Données critiques |
| `Standard_GZRS` | ZRS + copie dans une autre région Azure | Données critiques haute dispo |

Avec `GRS`, Azure réplique automatiquement vos données dans une région pairée (ex: `francecentral` → `francesouth`). En cas de panne du datacenter primaire, le failover est possible.

</details>

---

### 1.3 Récupérer la clé d'accès

> 🧠 **Pourquoi ?** Les commandes `az storage blob` ont besoin d'une clé pour s'authentifier au Storage Account. La variable d'environnement `AZURE_STORAGE_CONNECTION_STRING` est automatiquement lue par le CLI — plus besoin de passer `--account-name` et `--account-key` à chaque commande.

```bash
# Récupérer la connection string (contient la clé d'accès)
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name           "$SA_NAME" \
  --resource-group "$RG" \
  --query          connectionString \
  --output         tsv)

echo "Connection string récupérée ✅"
```

> 🔒 Cette connection string contient la clé d'accès complète au storage account — ne la commitez jamais dans Git.

---

## Partie 2 — Conteneur privé : logs de l'API (8 min)

### 2.1 Créer le conteneur privé

> 🧠 **Pourquoi ?** Un conteneur Blob est l'équivalent d'un dossier dans le Storage Account. `--public-access off` signifie qu'aucune URL publique ne peut accéder aux fichiers — seul un utilisateur avec la clé ou un token peut les lire. C'est le bon choix pour des logs contenant des données sensibles.

```bash
az storage container create \
  --name       "api-logs" \
  --public-access off
```

**Vérifier la création :**
```bash
az storage container list \
  --query "[].{Nom:name, Acces:properties.publicAccess}" \
  --output table
```

Résultat attendu :
```
Nom         Acces
----------  -------
api-logs    None
```

`None` = aucun accès public — seul un utilisateur authentifié peut lire ce conteneur.

---

### 2.2 Créer un fichier de log et l'uploader

> 🧠 **Pourquoi ?** On simule ici ce que ferait une application en production : écrire des logs et les envoyer vers le stockage centralisé. En réalité, c'est l'App Service ou la Function App qui écrirait ces fichiers programmatiquement via le SDK Azure.

Créez un fichier de log sur votre machine :

```bash
cat > access-log.txt << 'EOF'
2024-06-18 09:12:33 - GET /api/hello - 200 OK - 45ms - App Service
2024-06-18 09:12:47 - GET /api/hello - 200 OK - 12ms - Azure Functions
2024-06-18 09:13:01 - GET /api/hello - 200 OK - 38ms - Container Instances
EOF
```

Uploadez-le dans le conteneur privé :

```bash
az storage blob upload \
  --container-name "api-logs" \
  --file           "access-log.txt" \
  --name           "access-log.txt" \
  --overwrite
```

**Vérifier que le blob est présent :**
```bash
az storage blob list \
  --container-name "api-logs" \
  --query          "[].{Nom:name, Taille:properties.contentLength, Date:properties.lastModified}" \
  --output         table
```

---

### 2.3 Tenter d'accéder au blob sans authentification

> 🧠 **Pourquoi ?** Cette étape prouve concrètement que le conteneur est bien privé. On obtient l'URL publique du blob et on tente d'y accéder sans credential — ce qui doit échouer.

Récupérez l'URL publique du blob :

```bash
URL=$(az storage blob url \
  --container-name "api-logs" \
  --name           "access-log.txt" \
  --output         tsv)

echo "$URL"
curl -s "$URL"
```

Résultat attendu :
```xml
<?xml version="1.0" encoding="utf-8"?>
<Error>
  <Code>ResourceNotFound</Code>
  <Message>The specified resource does not exist.</Message>
</Error>
```

> ❓ **Question :** Azure renvoie "resource does not exist" plutôt que "accès refusé". Pourquoi Azure cache-t-il l'existence du fichier aux utilisateurs non authentifiés ? Quel est l'avantage sécuritaire de ce comportement ?

<details>
<summary>💡 Correction</summary>

C'est le principe de **security through obscurity** appliqué à la détection de ressources.

Si Azure répondait "403 Forbidden" (accès refusé), un attaquant saurait que le fichier **existe** — il pourrait alors tenter des attaques par force brute sur les tokens ou essayer d'autres méthodes d'accès.

En répondant "404 Not Found", Azure ne révèle pas l'existence du blob. L'attaquant ne sait pas s'il vise un fichier inexistant ou un fichier protégé — ce qui réduit la surface d'attaque.

C'est le même comportement que GitHub sur les repos privés : `github.com/user/repo-prive` répond 404 (pas 403) pour un utilisateur non autorisé.

</details>

---

### 2.4 Accéder au blob avec une SAS URL (accès temporaire)

> 🧠 **Pourquoi ?** Dans la vraie vie, on a parfois besoin de donner un accès temporaire à un fichier privé sans partager la clé principale — par exemple, envoyer un lien de téléchargement valable 1 heure à un partenaire externe. La **SAS (Shared Access Signature)** est une URL signée cryptographiquement avec une date d'expiration.

```bash
# Générer une SAS valable 1 heure
EXPIRY=$(date -u -d "+1 hour" '+%Y-%m-%dT%H:%MZ' 2>/dev/null || \
         date -u -v+1H '+%Y-%m-%dT%H:%MZ')   # macOS

SAS_URL=$(az storage blob generate-sas \
  --container-name "api-logs" \
  --name           "access-log.txt" \
  --permissions    r \
  --expiry         "$EXPIRY" \
  --full-uri \
  --output         tsv)

echo "SAS URL (valable 1h) :"
echo "$SAS_URL"
```

Testez l'accès :
```bash
curl -s "$SAS_URL"
```

Cette fois vous devriez voir le contenu du fichier log.

> 💡 **Cas d'usage réel :** Une API peut générer des SAS URLs à la volée pour permettre à des clients autorisés de télécharger des fichiers spécifiques pendant une durée limitée — sans jamais exposer la clé principale.

---

## Partie 3 — Conteneur public : configuration de l'API (8 min)

### 3.1 Créer le conteneur public

> 🧠 **Pourquoi ?** Un fichier de configuration que tous les clients de l'API doivent télécharger au démarrage n'a pas besoin d'être protégé — au contraire, il doit être accessible sans authentification. `--public-access blob` autorise la lecture anonyme sur les blobs sans exposer la liste complète du conteneur.

```bash
az storage container create \
  --name        "api-config" \
  --public-access blob
```

> `--public-access blob` : lecture anonyme autorisée sur les blobs, mais pas la liste des blobs du conteneur.

**Vérifier les deux conteneurs :**
```bash
az storage container list \
  --query "[].{Nom:name, Acces:properties.publicAccess}" \
  --output table
```

Résultat attendu :
```
Nom          Acces
-----------  ------
api-config   blob
api-logs     None
```

---

### 3.2 Créer et uploader le fichier de configuration

```bash
cat > config.json << 'EOF'
{
  "app": "AzureTech",
  "version": "1.0",
  "environment": "production",
  "endpoints": ["/api/hello", "/api/status"]
}
EOF
```

```bash
az storage blob upload \
  --container-name "api-config" \
  --file           "config.json" \
  --name           "config.json" \
  --content-type   "application/json" \
  --overwrite
```

---

### 3.3 Vérifier l'accès public

```bash
CONFIG_URL=$(az storage blob url \
  --container-name "api-config" \
  --name           "config.json" \
  --output         tsv)

echo "URL publique : $CONFIG_URL"
curl -s "$CONFIG_URL"
```

Résultat attendu :
```json
{
  "app": "AzureTech",
  "version": "1.0",
  "environment": "production",
  "endpoints": ["/api/hello", "/api/status"]
}
```

> ❓ **Question :** Ce fichier est accessible par n'importe qui sans authentification. Quelles informations ne devrait-on **jamais** mettre dans un fichier de configuration public ?

<details>
<summary>💡 Correction</summary>

Les informations à ne **jamais** exposer dans un fichier public :

- **Clés d'API** (Stripe, SendGrid, OpenAI, etc.) — permettent d'utiliser le service à vos frais
- **Mots de passe** de toute nature
- **Chaînes de connexion** à une base de données (contiennent identifiant + mot de passe + host)
- **Clés de storage Azure** — donnent accès complet au Storage Account
- **URLs internes** de vos services (révèlent l'architecture interne)
- **Informations d'environnement sensibles** (noms de serveurs internes, IPs privées)

Un fichier de config public peut contenir : des URLs d'endpoints publics, des numéros de version, des feature flags, des URLs de CDN.

En pratique, les secrets doivent être injectés via des **variables d'environnement** au démarrage de l'application (App Service > Configuration > Application settings), jamais stockés dans un fichier versionné ou public.

</details>

---

## Partie 4 — Comparaison et exploration (5 min)

### 4.1 Lister tous les blobs des deux conteneurs

```bash
echo "=== Conteneur api-logs (privé) ==="
az storage blob list \
  --container-name "api-logs" \
  --query          "[].{Nom:name, Taille:properties.contentLength}" \
  --output         table

echo ""
echo "=== Conteneur api-config (public) ==="
az storage blob list \
  --container-name "api-config" \
  --query          "[].{Nom:name, Taille:properties.contentLength}" \
  --output         table
```

### 4.2 Explorer les options de redondance

```bash
# Lister les SKUs disponibles pour le storage à francecentral
az storage account list-skus \
  --location "$LOCATION" \
  --query    "[].{SKU:name, Type:tier}" \
  --output   table
```

> ❓ **Question :** En regardant les SKUs disponibles, quel est le coût principal d'un passage de `Standard_LRS` à `Standard_GRS` ? Quel compromis faites-vous ?

<details>
<summary>💡 Correction</summary>

Le passage de `LRS` à `GRS` **double approximativement le coût de stockage** — Azure doit stocker deux copies de vos données dans deux régions différentes.

Le compromis est entre **coût** et **résilience** :

- `LRS` : moins cher, mais si le datacenter brûle, les données sont perdues
- `GRS` : deux fois plus cher, mais survit à une panne complète d'une région Azure

Pour un TP ou du stockage de logs non critiques → `Standard_LRS` est approprié.
Pour des données métier en production (contrats, paiements, données clients) → au minimum `Standard_ZRS`, idéalement `Standard_GRS`.

</details>

---

## Partie 5 — Intégration dans provision.sh

Les commandes suivantes sont prêtes à être ajoutées dans votre `provision.sh` existant après la création du Storage Account :

```bash
# ── Conteneurs Blob ───────────────────────────────────────────────────────────
echo ""
echo "▶ Création des conteneurs Blob..."

export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name           "$SA_NAME" \
  --resource-group "$RG" \
  --query          connectionString \
  --output         tsv)

az storage container create --name "api-logs"   --public-access off
az storage container create --name "api-config" --public-access blob

echo "✅ Conteneurs créés : api-logs (privé) / api-config (public)"

# Upload des fichiers exemples
echo '2024-06-18 09:12:33 - GET /api/hello - 200 OK' > /tmp/access-log.txt
az storage blob upload --container-name "api-logs"   --file /tmp/access-log.txt --name "access-log.txt" --overwrite

echo '{"app":"AzureTech","version":"1.0","endpoints":["/api/hello"]}' > /tmp/config.json
az storage blob upload --container-name "api-config" --file /tmp/config.json   --name "config.json"    --overwrite --content-type "application/json"

CONFIG_URL=$(az storage blob url --container-name "api-config" --name "config.json" --output tsv)
echo "✅ config.json accessible publiquement : $CONFIG_URL"
```

Et dans `destroy.sh`, ajouter avant la suppression du storage account :

```bash
# Vider les conteneurs avant de supprimer le storage account
if az storage account show --name "$SA_NAME" --resource-group "$RG" &>/dev/null; then
  CONN=$(az storage account show-connection-string \
    --name "$SA_NAME" --resource-group "$RG" --query connectionString --output tsv)
  export AZURE_STORAGE_CONNECTION_STRING="$CONN"
  az storage container delete --name "api-logs"   2>/dev/null || true
  az storage container delete --name "api-config" 2>/dev/null || true
fi
```

---

## 🧹 Nettoyage

```bash
# Supprimer les fichiers locaux créés pendant le TP
rm -f access-log.txt config.json

# Supprimer le storage account (supprime automatiquement tous les conteneurs et blobs)
az storage account delete \
  --name           "$SA_NAME" \
  --resource-group "$RG" \
  --yes

echo "✅ Storage account supprimé"

# Vérification
az storage account list \
  --resource-group "$RG" \
  --query          "[].name" \
  --output         table
```

---

## ✅ Ce que vous avez appris

- Créer un **Storage Account** avec az CLI et comprendre les paramètres SKU et kind
- Créer des **conteneurs Blob** avec des niveaux d'accès différents (`off` vs `blob`)
- **Uploader** des fichiers avec `az storage blob upload`
- Générer une **SAS URL** pour un accès temporaire et sécurisé sans exposer la clé principale
- Comprendre la différence entre les options de **redondance** (LRS, ZRS, GRS, GZRS)
- Intégrer ces commandes dans un script `provision.sh` réutilisable

---

*Formation DevSecOps Azure — Simplon*