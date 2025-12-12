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

# ================= INICIO DE INSTALACIÓN =================
Write-Host ""
Write-Host "--- Iniciando Instalación en: $InstancePath ---" -ForegroundColor Cyan

# 1. VERIFICAR JAVA
Write-Host "Verificando Java..." -ForegroundColor Yellow -NoNewline
try {
    $javaVer = java -version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Java no detectado." }
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " No detectado" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " Java no está instalado. Descargando e instalando Java 21..." -ForegroundColor Cyan
    
    try {
        # Descargar instalador portable de Java 21 (ZIP)
        $JavaZipUrl = "https://aka.ms/download-jdk/microsoft-jdk-21.0.5-windows-x64.zip"
        $JavaZipPath = "$env:TEMP\jdk-21.zip"
        $JavaInstallDir = "$env:LOCALAPPDATA\Java\jdk-21"
        
        Write-Host " Descargando Java 21 (portable)..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $JavaZipUrl -OutFile $JavaZipPath -UseBasicParsing
        
        Write-Host " Extrayendo Java 21..." -ForegroundColor Yellow
        
        if (!(Test-Path -Path $JavaInstallDir)) {
            New-Item -ItemType Directory -Force -Path $JavaInstallDir | Out-Null
        }
        
        # Extraer el ZIP
        Expand-Archive -Path $JavaZipPath -DestinationPath "$env:LOCALAPPDATA\Java" -Force
        
        # Buscar el directorio real del JDK
        $jdkFolder = Get-ChildItem -Path "$env:LOCALAPPDATA\Java" -Directory | Where-Object { $_.Name -like "jdk-21*" } | Select-Object -First 1
        
        if ($jdkFolder) {
            $JavaBinPath = "$($jdkFolder.FullName)\bin"
            
            # Agregar Java al PATH del usuario (permanente)
            $currentUserPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            if ($currentUserPath -notlike "*$JavaBinPath*") {
                [System.Environment]::SetEnvironmentVariable("Path", "$currentUserPath;$JavaBinPath", "User")
            }
            
            # Actualizar PATH para la sesión actual
            $env:Path = "$env:Path;$JavaBinPath"
            
            Write-Host "[OK] Java 21 instalado correctamente en: $($jdkFolder.FullName)" -ForegroundColor Green
            Write-Host ""
            Write-Host "[AVISO] Java se instaló correctamente." -ForegroundColor Yellow
            Write-Host "Por favor, cierra esta ventana y ejecuta el instalador nuevamente para que se detecte Java." -ForegroundColor Yellow
            
            # Limpiar archivo temporal
            Remove-Item $JavaZipPath -Force -ErrorAction SilentlyContinue
            
            Pause
            Exit
        } else {
            throw "No se encontró el directorio de Java después de la extracción"
        }
    } catch {
        Write-Host ""
        Write-Host "[ERROR] No se pudo instalar Java automáticamente: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Por favor, descarga e instala Java 21 manualmente desde:" -ForegroundColor Yellow
        Write-Host "https://learn.microsoft.com/java/openjdk/download" -ForegroundColor Cyan
        Write-Host ""
        Pause
        Exit
    }
}

# 2. VERIFICAR E INSTALAR FABRIC
Write-Host "Verificando Fabric..." -ForegroundColor Yellow -NoNewline
$FabricVersionID = "fabric-loader-$FabricLoaderVer-$MinecraftVer"
$FabricVersionPath = "$MinecraftRoot\versions\$FabricVersionID"
$FabricJsonFile = "$FabricVersionPath\$FabricVersionID.json"

$FabricYaInstalado = Test-Path $FabricJsonFile

if ($FabricYaInstalado) {
    Write-Host " OK" -ForegroundColor Green
    Write-Host "$FabricVersionID ya está instalado. Omitiendo instalación." -ForegroundColor Green
} else {
    Write-Host " Instalando..." -ForegroundColor Yellow
    $FabricInstallerUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"
    $InstallerPath = "$env:TEMP\fabric-installer.jar"

    try {
        Invoke-WebRequest -Uri $FabricInstallerUrl -OutFile $InstallerPath
        
        # Instalar Fabric (Client) sin crear perfil automático (-noprofile)
        $installArgs = "-jar `"$InstallerPath`" client -dir `"$MinecraftRoot`" -mcversion $MinecraftVer -loader $FabricLoaderVer -noprofile"
        Start-Process -FilePath "java" -ArgumentList $installArgs -Wait -NoNewWindow
        
        Write-Host "[OK] $FabricVersionID instalado correctamente" -ForegroundColor Green
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

# ================= LISTA DE MODS =================
# URL del archivo JSON con la lista de mods en GitHub
$ModListUrl = "https://raw.githubusercontent.com/USMQL/cobble-installer/refs/heads/main/modlist.json"

Write-Host "Cargando lista de mods..." -ForegroundColor Yellow -NoNewline
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
    
    Write-Host " OK ($($ModList.Count) mods)" -ForegroundColor Green
} catch {
    Write-Host " ERROR" -ForegroundColor Red
    Write-Host "No se pudo descargar la lista de mods: $_" -ForegroundColor Red
    Pause
    Exit
}

Write-Host "`nDescargando Mods..." -ForegroundColor Yellow
$modIndex = 0
$totalMods = $ModList.Count
foreach ($modEntry in $ModList.GetEnumerator()) {
    $modIndex++
    try {
        $modBaseName = $modEntry.Key
        $url = $modEntry.Value
        $fileName = [System.IO.Path]::GetFileName($url)
        
        if ($fileName -notlike "*.jar" -or $fileName -eq "download") {
            $fileName = "$modBaseName-$(Get-Date -Format 'yyyyMMdd').jar"
        }

        $fullPath = "$ModsDir\$fileName"
        
        # Buscar si existe algún archivo que comience con el nombre base del mod
        $existingMods = Get-ChildItem -Path $ModsDir -Filter "$modBaseName*.jar" -ErrorAction SilentlyContinue
        
        if ($existingMods) {
            # Verificar si ya existe exactamente el mismo archivo
            $exactMatch = $existingMods | Where-Object { $_.Name -eq $fileName }
            
            if ($exactMatch) {
                Write-Host "[$modIndex/$totalMods] Ya existe: $fileName (Omitiendo)" -ForegroundColor DarkGray
            } else {
                # Existe una versión diferente, eliminarla y descargar la nueva
                foreach ($oldMod in $existingMods) {
                    Write-Host "[$modIndex/$totalMods] Eliminando versión antigua: $($oldMod.Name)" -ForegroundColor Yellow
                    Remove-Item $oldMod.FullName -Force
                }
                Write-Host "[$modIndex/$totalMods] Descargando nueva versión: $fileName" -ForegroundColor Cyan
                Invoke-WebRequest -Uri $url -OutFile $fullPath
                Write-Host "[$modIndex/$totalMods] [OK] $fileName descargado" -ForegroundColor Green
            }
        } else {
            # No existe ninguna versión del mod, descargarlo
            Write-Host "[$modIndex/$totalMods] Descargando: $fileName" -ForegroundColor Cyan
            Invoke-WebRequest -Uri $url -OutFile $fullPath
            Write-Host "[$modIndex/$totalMods] [OK] $fileName descargado" -ForegroundColor Green
        }
    } catch {
        Write-Host " [!] Error procesando $($modEntry.Key): $_" -ForegroundColor Red
    }
}

# 5. DESCARGAR Y APLICAR CONFIGURACIONES
Write-Host "Descargando configuraciones..." -ForegroundColor Yellow
$GitHubRepo = "USMQL/cobble-installer"
$GitHubBranch = "main"

# Función recursiva para descargar contenido de carpetas
function Download-GitHubFolder {
    param(
        [string]$RepoPath,
        [string]$LocalPath,
        [string]$Repo,
        [string]$Branch,
        [bool]$SkipExisting = $false
    )
    
    $apiUrl = "https://api.github.com/repos/$Repo/contents/$RepoPath`?ref=$Branch"
    
    try {
        # Pequeña pausa para evitar rate limiting
        Start-Sleep -Milliseconds 500
        
        $response = Invoke-RestMethod -Uri $apiUrl -Headers @{
            "User-Agent" = "PowerShell-Minecraft-Installer"
        } -TimeoutSec 30

        foreach ($item in $response) {
            if ($item.type -eq "file") {
                $fileName = $item.name
                $downloadUrl = $item.download_url
                $destinationPath = Join-Path $LocalPath $fileName
                
                # Si SkipExisting es true y el archivo ya existe, omitirlo
                if ($SkipExisting -and (Test-Path $destinationPath)) {
                    Write-Host "`r -> $RepoPath/$fileName (omitido, ya existe)                                    " -ForegroundColor DarkGray
                    continue
                }
                
                try {
                    Write-Host "`r -> $RepoPath/$fileName                                                 " -NoNewline -ForegroundColor Cyan
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $destinationPath -TimeoutSec 30
                } catch {
                    Write-Host "`n [!] Error descargando $fileName : $_" -ForegroundColor Red
                }
            } elseif ($item.type -eq "dir") {
                $subDirName = $item.name
                $subDirPath = Join-Path $LocalPath $subDirName
                
                if (!(Test-Path -Path $subDirPath)) {
                    New-Item -ItemType Directory -Force -Path $subDirPath | Out-Null
                }
                
                # Llamada recursiva para subdirectorios
                Download-GitHubFolder -RepoPath "$RepoPath/$subDirName" -LocalPath $subDirPath -Repo $Repo -Branch $Branch -SkipExisting $SkipExisting
            }
        }
    } catch {
        Write-Host "`n [!] Error accediendo a $RepoPath : $_" -ForegroundColor Red
    }
}

try {
    # Lista de carpetas a descargar
    $downloads = @(
        @{ RepoPath = "config"; LocalPath = "$InstancePath\config"; SkipExisting = $false }
    )
    
    # Descargar carpetas
    foreach ($download in $downloads) {
        if (!(Test-Path -Path $download.LocalPath)) {
            New-Item -ItemType Directory -Force -Path $download.LocalPath | Out-Null
        }
        Download-GitHubFolder -RepoPath $download.RepoPath -LocalPath $download.LocalPath -Repo $GitHubRepo -Branch $GitHubBranch -SkipExisting $download.SkipExisting
    }
    
    # Descargar options.txt
    try {
        $optionsPath = "$InstancePath\options.txt"
        if (Test-Path $optionsPath) {
            Write-Host "`r -> options.txt (omitido, ya existe)                                                   " -ForegroundColor DarkGray
        } else {
            $optionsUrl = "https://raw.githubusercontent.com/$GitHubRepo/$GitHubBranch/options.txt"
            Write-Host "`r -> options.txt                                                                        " -NoNewline -ForegroundColor Cyan
            Invoke-WebRequest -Uri $optionsUrl -OutFile $optionsPath -TimeoutSec 30
        }
    } catch {
        # Si options.txt no existe en el repo, no es un error crítico
    }
    
    Write-Host "`r[OK] Configuraciones y recursos descargados correctamente.                                     " -ForegroundColor Green
} catch {
    Write-Host "`n[AVISO] Algunos recursos no pudieron descargarse" -ForegroundColor Yellow
}

# 6. CONFIGURAR LAUNCHER_PROFILES.JSON
Write-Host "Configurando perfil..." -ForegroundColor Yellow
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
        Write-Host " Se detectó un perfil existente de '$ProfileName'." -ForegroundColor DarkYellow
        Write-Host " Actualizando perfil con la nueva configuración..." -ForegroundColor Yellow
        
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
            javaArgs      = "-Xmx4G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"
            lastUsed      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            lastVersionId = $FabricVersionID
            name          = $ProfileName
            resolution    = [PSCustomObject]@{
                height = 900
                width  = 1600
            }
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
    Write-Host "Esto se debe a que no hay una instalación previa de Minecraft Launcher." -ForegroundColor Red
    Write-Host "Si utilizas un launcher alternativo, puedes crear un perfil manualmente que apunte a la carpeta de la instancia." -ForegroundColor Red
    Write-Host "Configura el perfil con:" -ForegroundColor Red
    Write-Host "  - Nombre: $ProfileName" -ForegroundColor Red
    Write-Host "  - Versión: $FabricVersionID" -ForegroundColor Red
    Write-Host "  - Carpeta de juego: $InstancePath" -ForegroundColor Red
}

Write-Host "`n=============================================================================="
Write-Host "Instalación Completada" -ForegroundColor Green
Write-Host "=============================================================================="
Write-Host "Abre o reinicia Minecraft Launcher y selecciona el perfil: $ProfileName" -ForegroundColor Cyan
Write-Host ""
Pause