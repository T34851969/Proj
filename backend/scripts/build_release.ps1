# AI Resume Server - Windows 自包含发行包构建(零网络)
# 在 Windows 机器(已安装 Python 3.11+ 并建好 backend\.venv、client\dist)上执行:
#   powershell -ExecutionPolicy Bypass -File backend\scripts\build_release.ps1            # lite
#   powershell -ExecutionPolicy Bypass -File backend\scripts\build_release.ps1 -Full      # full
# 产出: dist-release\ai-resume-server-windows-x86_64-<lite|full>.zip
#   -Stage <dir>  不打 zip,直接把发行包布局暂存到指定目录(供 Tauri resources 使用)
param(
    [switch]$Full,
    [string]$Out = (Join-Path $PSScriptRoot "..\..\dist-release"),
    [string]$Stage = ""
)

$ErrorActionPreference = "Stop"
$root    = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$backend = Join-Path $root "backend"
$venvSite = Join-Path $backend ".venv\Lib\site-packages"

if (-not (Test-Path $venvSite)) { Write-Error "未找到 $venvSite(请先 pip install -r requirements.txt)" }
if (-not (Test-Path (Join-Path $root "client\dist\index.html"))) { Write-Error "缺少 client\dist\index.html(请先 npm run build)" }

$variant = if ($Full) { "full" } else { "lite" }
$name    = "ai-resume-server-windows-x86_64-$variant"
# 注意:PowerShell 变量名不区分大小写,布局变量不能与参数同名(原 $stage 与 $Stage 冲突),
# 否则此处赋值后参数 $Stage 非空,末尾的 Stage 判断恒真,zip 模式永远不执行
$layoutDir = if ($Stage -ne "") { $Stage } else { Join-Path ([System.IO.Path]::GetTempPath()) "$name" }

Write-Host "== 构建发行包: $name =="
Write-Host "   布局目录: $layoutDir"
if (Test-Path $layoutDir) { Remove-Item -Recurse -Force $layoutDir }
# 只预建 data 与 runtime;app/static/deploy 由下方 Copy-Item 直接落位
# (PowerShell 目标目录已存在时会把源拷成子目录,先建后拷会嵌套一层)
New-Item -ItemType Directory -Force -Path "$layoutDir\data", "$layoutDir\runtime" | Out-Null

Copy-Item -Recurse -Force (Join-Path $backend "app")     "$layoutDir\app"
Copy-Item (Join-Path $backend "data\*.json")              "$layoutDir\data"
Copy-Item -Recurse -Force (Join-Path $root "client\dist") "$layoutDir\static"
Copy-Item -Recurse -Force (Join-Path $root "deploy")      "$layoutDir\deploy"
Copy-Item -Force (Join-Path $root ".env.example")         "$layoutDir\.env.example"
Copy-Item -Force (Join-Path $root "deploy\README-DEPLOY.md") "$layoutDir\README-DEPLOY.md"

# 解释器:基础安装的 python.exe(venv 的 exe 是重定向器,离开 pyvenv.cfg 无法启动)
# + 官方安装目录的 Lib(标准库,注意用 \* 拷内容,否则 PowerShell 会嵌套成 Lib\Lib)
# + DLLs(C 扩展模块,_socket/ssl 等运行必需)。基础 exe 以自身目录为 prefix,可移植。
$baseHome = (Get-Content (Join-Path $backend ".venv\pyvenv.cfg") | Select-String "^home\s*=\s*(.+)$").Matches[0].Groups[1].Value.Trim()
Copy-Item (Join-Path $baseHome "python.exe") "$layoutDir\runtime\python.exe"
Copy-Item -Recurse -Force (Join-Path $baseHome "DLLs") "$layoutDir\runtime\DLLs"
New-Item -ItemType Directory -Force -Path "$layoutDir\runtime\Lib\site-packages" | Out-Null
Copy-Item -Force (Join-Path $baseHome "Lib\*.py") "$layoutDir\runtime\Lib\"
Copy-Item -Recurse -Force (Join-Path $baseHome "Lib\*") "$layoutDir\runtime\Lib\" -Exclude "__pycache__"
# python3.dll / python313.dll 与 vcruntime 跟随解释器,一并拷贝
Get-ChildItem $baseHome -Filter "python*.dll" | Copy-Item -Destination "$layoutDir\runtime"
Get-ChildItem $baseHome -Filter "vcruntime*.dll" | Copy-Item -Destination "$layoutDir\runtime"

# site-packages
Copy-Item -Recurse -Force (Join-Path $venvSite "*") "$layoutDir\runtime\Lib\site-packages\"

if (-not $Full) {
    Write-Host "== lite: 剔除嵌入模型栈 =="
    $exclude = "torch","torchgen","functorch","include","sentence_transformers","transformers",
               "tokenizers","safetensors","huggingface_hub","hf_xet","scipy","sklearn","sympy",
               "mpmath","networkx"
    foreach ($e in $exclude) {
        Get-ChildItem "$layoutDir\runtime\Lib\site-packages" -Filter "$e*" -Directory |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Get-ChildItem $layoutDir -Recurse -Directory -Filter "__pycache__" |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 自举验证
& "$layoutDir\runtime\python.exe" -c "import fastapi, uvicorn, numpy, docx, pypdf; print('runtime OK')"

if ($Stage -ne "") {
    Write-Host "== 完成(Stage 模式,未压缩): $layoutDir =="
    exit 0
}

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$zip = Join-Path $Out "$name.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $layoutDir -DestinationPath $zip
Remove-Item -Recurse -Force $layoutDir
Write-Host "== 完成: $zip =="
Get-Item $zip | Select-Object Name, @{n="SizeMB";e={[math]::Round($_.Length/1MB,1)}}
