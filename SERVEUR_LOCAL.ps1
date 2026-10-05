# Serveur HTTP local pour ouvrir le viewer sans installer Python.
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$port = 8765
$listener = $null
# Ne jamais ouvrir un autre viewer par erreur si le port 8765 est deja pris.
# Selectionner un port libre (8765-8790) pour CETTE copie de la mission.
foreach($candidate in 8765..8790) {
    $tryListener = New-Object System.Net.HttpListener
    $tryListener.Prefixes.Add("http://localhost:$candidate/")
    try { $tryListener.Start(); $listener=$tryListener; $port=$candidate; break }
    catch { $tryListener.Close() }
}
if(-not $listener) { Write-Host 'Aucun port disponible entre 8765 et 8790. Fermez les anciens serveurs AED.' -ForegroundColor Red; Read-Host 'Entree'; exit 1 }
try {
    Start-Process "http://localhost:$port/"
    Write-Host "AED Viewer ACCOAST : http://localhost:$port/" -ForegroundColor Cyan
    Write-Host 'Laisser cette fenetre ouverte. Ctrl+C pour quitter.'
    $mime = @{'.html'='text/html; charset=utf-8';'.js'='text/javascript; charset=utf-8';'.css'='text/css';'.json'='application/json';'.dzi'='application/xml';'.jpg'='image/jpeg';'.jpeg'='image/jpeg';'.png'='image/png';'.svg'='image/svg+xml';'.webp'='image/webp';'.ico'='image/x-icon'}
    while($listener.IsListening) {
        $ctx = $listener.GetContext()
        try {
            $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
            if([string]::IsNullOrEmpty($rel)) {$rel='index.html'}
            if($rel.Contains('..') -or $rel.Contains(':') -or $rel.Contains('\')) {throw 'URL interdite'}
            $path = [IO.Path]::GetFullPath((Join-Path $root ($rel.Replace('/',[IO.Path]::DirectorySeparatorChar))))
            if(-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Chemin interdit'}
            if(-not [IO.File]::Exists($path)) {$ctx.Response.StatusCode=404}
            else {
                $extension=[IO.Path]::GetExtension($path).ToLowerInvariant()
                $ctx.Response.ContentType=if($mime.ContainsKey($extension)){$mime[$extension]}else{'application/octet-stream'}
                $ctx.Response.Headers.Add('X-Content-Type-Options','nosniff')
                $file=[IO.File]::OpenRead($path)
                try {$ctx.Response.ContentLength64=$file.Length; $file.CopyTo($ctx.Response.OutputStream)} finally {$file.Dispose()}
            }
        } catch {
            try{$ctx.Response.StatusCode=400}catch{}
            Write-Warning $_.Exception.Message
        } finally {try{$ctx.Response.Close()}catch{}}
    }
} catch {Write-Host ('Echec du serveur : '+$_.Exception.Message) -ForegroundColor Red; Read-Host 'Appuyez sur Entree'} finally {if($listener.IsListening){$listener.Stop()};$listener.Close()}
