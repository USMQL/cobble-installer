[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ================= CONFIGURACIÓN BÁSICA =================
$MinecraftVer = "1.21.1"
$FabricLoaderVer = "0.18.4"
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
$ProfileIcon = "data:image/png;base64,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"

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
        $jsonContent.profiles.$IdPerfilExistente.icon = $ProfileIcon
        
        # Guardamos cambios
        $jsonContent | ConvertTo-Json -Depth 10 | Set-Content $ProfilesFile
        Write-Host "[OK] Perfil actualizado correctamente." -ForegroundColor Green
    }

    # Si decidimos crear uno nuevo
    if ($CrearNuevoPerfil) {
        $NewProfileId = [Guid]::NewGuid().ToString()
        $NewProfile = [PSCustomObject]@{
            created       = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            icon          = $ProfileIcon
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