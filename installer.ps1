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
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "      INSTALADOR DE MODPACK - $ProfileName   " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
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
# Diccionario de Mods: Clave = nombre base del mod, Valor = URL de descarga
# El nombre base se usa para detectar y eliminar versiones antiguas
$ModList = @{
    "fabric-api" = "https://cdn.modrinth.com/data/P7dR8mSH/versions/m6zu1K31/fabric-api-0.116.7+1.21.1.jar"
    "accessories-fabric" = "https://cdn.modrinth.com/data/jtmvUHXj/versions/uPPIhLTH/accessories-fabric-1.1.0-beta.52+1.21.1.jar"
    "architectury" = "https://cdn.modrinth.com/data/lhGA9TYQ/versions/Wto0RchG/architectury-13.0.8-fabric.jar"
    "BiomesOPlenty" = "https://cdn.modrinth.com/data/HXF82T3G/versions/YPm4arUa/BiomesOPlenty-fabric-1.21.1-21.1.0.13.jar"
    "chefsdelight" = "https://cdn.modrinth.com/data/pvcsfne4/versions/Sur0Lj66/chefsdelight-1.0.5-fabric-1.21.1.jar"
    "Cobblemon" = "https://cdn.modrinth.com/data/MdwFAVRL/versions/s64m1opn/Cobblemon-fabric-1.7.1+1.21.1.jar"
    "mega_showdown" = "https://cdn.modrinth.com/data/SszvX85I/versions/f05e8UwL/mega_showdown-fabric-1.4.4+1.7.1+1.21.1.jar"
    "farmers-cutting-biomes-o-plenty" = "https://cdn.modrinth.com/data/QWfaJXEc/versions/ErfSMjj4/farmers-cutting-biomes-o-plenty-1.21-2.0.0-fabric.jar"
    "farmers-cutting-regions-unexplored" = "https://cdn.modrinth.com/data/lFKDc2ny/versions/GrhjtZEe/farmers-cutting-regions-unexplored-1.21.1-1.1a-fabric.jar"
    "FarmersDelight" = "https://cdn.modrinth.com/data/7vxePowz/versions/vj4n2BSl/FarmersDelight-1.21.1-3.2.2+refabricated.jar"
    "farmersknives" = "https://cdn.modrinth.com/data/uc3VdfLM/versions/2wn5TnBh/farmersknives-fabric-1.21.1-4.0.4.jar"
    "ForgeConfigAPIPort" = "https://cdn.modrinth.com/data/ohNO6lps/versions/N5qzq0XV/ForgeConfigAPIPort-v21.1.6-1.21.1-Fabric.jar"
    "GlitchCore" = "https://cdn.modrinth.com/data/s3dmwKy5/versions/lbSHOhee/GlitchCore-fabric-1.21.1-2.1.0.0.jar"
    "jei" = "https://cdn.modrinth.com/data/u6dRKJwZ/versions/P23di0ns/jei-1.21.1-fabric-19.25.1.332.jar"
    "owo-lib" = "https://cdn.modrinth.com/data/ccKDOlHs/versions/JB1fLQnc/owo-lib-0.12.15.4+1.21.jar"
    "regions_unexplored" = "https://cdn.modrinth.com/data/Tkikq67H/versions/ZS3DtSyB/regions_unexplored-fabric-1.21.1-0.5.6.1.jar"
    "TerraBlender" = "https://cdn.modrinth.com/data/kkmrDlKT/versions/XNtIBXyQ/TerraBlender-fabric-1.21.1-4.1.0.8.jar"
    "trinkets" = "https://cdn.modrinth.com/data/5aaWibi9/versions/JagCscwi/trinkets-3.10.0.jar"
    # Ejemplo de cómo agregar más mods:
    # "sodium" = "https://cdn.modrinth.com/data/AANobbMI/versions/sodium-fabric-0.5.11.jar"
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