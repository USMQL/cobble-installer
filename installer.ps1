[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ================= CONFIGURACIÓN BÁSICA =================
$MinecraftVer = "1.21.1"
$FabricLoaderVer = "0.18.2"
$ProfileName = "Cobblemon USMQL"
$DefaultInstancePath = "$env:APPDATA\.minecraft\profiles\Cobblemon_USMQL" # Ruta por defecto
$MinecraftRoot = "$env:APPDATA\.minecraft"

# Cargar ensamblados necesarios para diálogos visuales
Add-Type -AssemblyName System.Windows.Forms

# ================= SELECCIÓN DE RUTA =================
Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "      INSTALADOR DE MODPACK - POKEMON: LAST SEMESTER - [$ProfileName]   " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ruta de instalación por defecto:" -ForegroundColor Yellow
Write-Host "   $DefaultInstancePath" -ForegroundColor White
Write-Host ""
Write-Host "Presiona [ENTER] para usar esta ruta." -ForegroundColor Green
Write-Host "Presiona [E] y luego Enter para ELEGIR otra carpeta..." -ForegroundColor Magenta

$seleccion = Read-Host "Opción"

if ($seleccion -eq "e" -or $seleccion -eq "E") {
    # Crear el diálogo de selección de carpeta
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Selecciona la carpeta donde se instalará el Modpack"
    $folderBrowser.ShowNewFolderButton = $true
    
    # Si la ruta por defecto existe (o su padre), intentar abrirla ahí
    if (Test-Path $DefaultInstancePath) { $folderBrowser.SelectedPath = $DefaultInstancePath }
    
    # Mostrar el diálogo y capturar el resultado
    $resultado = $folderBrowser.ShowDialog()
    
    if ($resultado -eq "OK") {
        $InstancePath = $folderBrowser.SelectedPath
        Write-Host "Carpeta seleccionada: $InstancePath" -ForegroundColor Green
    } else {
        Write-Host "Selección cancelada. Usando ruta por defecto." -ForegroundColor Yellow
        $InstancePath = $DefaultInstancePath
    }
} else {
    $InstancePath = $DefaultInstancePath
    Write-Host "Usando ruta por defecto." -ForegroundColor Green
}

# ================= LISTA DE MODS =================
# URL del archivo JSON con la lista de mods en GitHub
$ModListUrl = "https://raw.githubusercontent.com/USMQL/cobble-installer/refs/heads/main/modlist.json"

Write-Host "Descargando lista de mods..." -ForegroundColor Yellow
try {
    $webClient = New-Object System.Net.WebClient
    $webClient.Encoding = [System.Text.Encoding]::UTF8
    $modListJson = $webClient.DownloadString($ModListUrl)
    $modListData = $modListJson | ConvertFrom-Json
    $ModList = @{}
    
    # Convertir el objeto JSON a hashtable
    foreach ($property in $modListData.mods.PSObject.Properties) {
        $ModList[$property.Name] = $property.Value
    }
    
    Write-Host "[OK] Lista de mods cargada: $($ModList.Count) mod(s)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] No se pudo descargar la lista de mods: $_" -ForegroundColor Red
    Pause
    Exit
}

# ================= INICIO DE INSTALACIÓN =================
Write-Host ""
Write-Host "--- Iniciando Instalación en: $InstancePath ---" -ForegroundColor Cyan

# 1. VERIFICAR JAVA
try {
    $javaVer = java -version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Java no detectado." }
    Write-Host "[OK] Java detectado." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Java no está instalado o no está en el PATH." -ForegroundColor Red
    Pause
    Exit
}

# 2. VERIFICAR E INSTALAR FABRIC
Write-Host "Verificando instalación de Fabric..." -ForegroundColor Yellow
$FabricVersionID = "fabric-loader-$FabricLoaderVer-$MinecraftVer"
$FabricVersionPath = "$MinecraftRoot\versions\$FabricVersionID"
$FabricJsonFile = "$FabricVersionPath\$FabricVersionID.json"

$FabricYaInstalado = Test-Path $FabricJsonFile

if ($FabricYaInstalado) {
    Write-Host "[OK] Fabric $FabricVersionID ya está instalado. Saltando instalación." -ForegroundColor Green
} else {
    Write-Host "Fabric no encontrado. Descargando e instalando..." -ForegroundColor Yellow
    $FabricInstallerUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"
    $InstallerPath = "$env:TEMP\fabric-installer.jar"

    try {
        Invoke-WebRequest -Uri $FabricInstallerUrl -OutFile $InstallerPath
        
        # Instalar Fabric (Client) sin crear perfil automático (-noprofile)
        $installArgs = "-jar `"$InstallerPath`" client -dir `"$MinecraftRoot`" -mcversion $MinecraftVer -loader $FabricLoaderVer -noprofile"
        Start-Process -FilePath "java" -ArgumentList $installArgs -Wait -NoNewWindow
        
        Write-Host "[OK] Fabric instalado correctamente" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Fallo al instalar Fabric: $_" -ForegroundColor Red
        Exit
    }
}

# 3. CREAR DIRECTORIOS DEL PERFIL E INSTANCIA
$ModsDir = "$InstancePath\mods"

# Crear la carpeta raíz si no existe
if (!(Test-Path -Path $InstancePath)) {
    New-Item -ItemType Directory -Force -Path $InstancePath | Out-Null
}
# Crear la carpeta mods
if (!(Test-Path -Path $ModsDir)) {
    New-Item -ItemType Directory -Force -Path $ModsDir | Out-Null
}

# 4. DESCARGAR MODS
Write-Host "Descargando Mods..." -ForegroundColor Yellow
foreach ($modEntry in $ModList.GetEnumerator()) {
    try {
        $modBaseName = $modEntry.Key
        $url = $modEntry.Value
        $fileName = [System.IO.Path]::GetFileName($url)
        $fullPath = "$ModsDir\$fileName"
        
        # Buscar si existe algún archivo que comience con el nombre base del mod
        $existingMods = Get-ChildItem -Path $ModsDir -Filter "$modBaseName*.jar" -ErrorAction SilentlyContinue
        
        if ($existingMods) {
            # Verificar si ya existe exactamente el mismo archivo
            $exactMatch = $existingMods | Where-Object { $_.Name -eq $fileName }
            
            if ($exactMatch) {
                Write-Host " -> Ya existe: $fileName (Saltando)" -ForegroundColor Gray
            } else {
                # Existe una versión diferente, eliminarla y descargar la nueva
                foreach ($oldMod in $existingMods) {
                    Write-Host " -> Eliminando versión antigua: $($oldMod.Name)" -ForegroundColor Yellow
                    Remove-Item $oldMod.FullName -Force
                }
                Write-Host " -> Descargando nueva versión: $fileName" -ForegroundColor Cyan
                Invoke-WebRequest -Uri $url -OutFile $fullPath
                Write-Host " -> [OK] $fileName descargado" -ForegroundColor Green
            }
        } else {
            # No existe ninguna versión del mod, descargarlo
            Write-Host " -> Descargando: $fileName" -ForegroundColor Cyan
            Invoke-WebRequest -Uri $url -OutFile $fullPath
            Write-Host " -> [OK] $fileName descargado" -ForegroundColor Green
        }
    } catch {
        Write-Host " [!] Error procesando $($modEntry.Key): $_" -ForegroundColor Red
    }
}

# 5. CONFIGURAR LAUNCHER_PROFILES.JSON
Write-Host "Gestionando perfil del Launcher..." -ForegroundColor Yellow
$ProfilesFile = "$MinecraftRoot\launcher_profiles.json"
$BackupFile = "$MinecraftRoot\launcher_profiles_backup.json"

if (Test-Path $ProfilesFile) {
    # Hacemos backup primero
    Copy-Item $ProfilesFile $BackupFile -Force
    
    # Leemos el JSON
    $jsonContent = Get-Content $ProfilesFile -Raw | ConvertFrom-Json
    $FabricVersionID = "fabric-loader-$FabricLoaderVer-$MinecraftVer"

    # --- LÓGICA DE DETECCIÓN DE PERFIL EXISTENTE ---
    $PerfilExiste = $false
    $IdPerfilExistente = $null

    # Recorremos los perfiles existentes para ver si ya hay uno con nuestro nombre
    foreach ($key in $jsonContent.profiles.PSObject.Properties.Name) {
        if ($jsonContent.profiles.$key.name -eq $ProfileName) {
            $PerfilExiste = $true
            $IdPerfilExistente = $key
            break
        }
    }

    $CrearNuevoPerfil = $true

    if ($PerfilExiste) {
        Write-Host ""
        Write-Host "Se detectó un perfil existente llamado '$ProfileName'." -ForegroundColor Yellow
        Write-Host "Actualizando perfil con la nueva configuración..." -ForegroundColor Cyan
        
        $CrearNuevoPerfil = $false
        
        # Actualizamos los datos del perfil encontrado
        $jsonContent.profiles.$IdPerfilExistente.lastVersionId = $FabricVersionID
        $jsonContent.profiles.$IdPerfilExistente.gameDir = $InstancePath
        $jsonContent.profiles.$IdPerfilExistente.lastUsed = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        
        # Guardamos cambios
        $jsonContent | ConvertTo-Json -Depth 10 | Set-Content $ProfilesFile
        Write-Host "[OK] Perfil actualizado correctamente." -ForegroundColor Green
    }

    # Si decidimos crear uno nuevo
    if ($CrearNuevoPerfil) {
        $NewProfileId = [Guid]::NewGuid().ToString()
        $NewProfile = [PSCustomObject]@{
            created       = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            icon          = "Grass"
            lastUsed      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            lastVersionId = $FabricVersionID
            name          = $ProfileName
            type          = "custom"
            gameDir       = $InstancePath
        }

        # Añadir al JSON
        $jsonContent.profiles | Add-Member -MemberType NoteProperty -Name $NewProfileId -Value $NewProfile -Force
        $jsonContent | ConvertTo-Json -Depth 10 | Set-Content $ProfilesFile
        Write-Host "[OK] Perfil '$ProfileName' creado y configurado apuntando a: $InstancePath" -ForegroundColor Green
    }

} else {
    Write-Host "[ERROR] No se encontró launcher_profiles.json." -ForegroundColor Red
}

Write-Host "--- Instalación Completada ---" -ForegroundColor Cyan
Write-Host "Abre o reinicia tu Minecraft Launcher y selecciona el perfil: $ProfileName"
Pause