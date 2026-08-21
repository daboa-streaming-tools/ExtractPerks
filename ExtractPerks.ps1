<#
Dead by Daylight パーク一覧スクリーンショットから、ひし形のパークアイコンを
1つずつ切り出して連番PNGとして保存するスクリプト。

前提:
  - src フォルダ内の画像はすべて 1920x1080、同一UIレイアウト
    (インベントリ/パーク欄に 5x3=15個のひし形が並ぶ画面)であること。
  - ファイル名の並び順(アルファベット順)がそのまま日付順になっていること。

出力:
  - out フォルダに 0001.png, 0002.png ... という連番で、
    ひし形の外接正方形サイズに切り出した画像を保存する。
  - $RemoveBackground = $true の場合、ひし形の黒枠+紫背景も透過にし、
    白いアイコン線画だけを残す。
#>

$SrcDir = Join-Path $PSScriptRoot 'src'
$OutDir = Join-Path $PSScriptRoot 'out'
$RemoveBackground = $true   # $false にすると、ひし形の外側だけ透過(紫背景は残す)

# --- ひし形グリッド座標(1920x1080のロードアウト画面で実測・検証済み) ---
$Row1X = 395, 519, 642, 768, 890
$Row2X = 457, 581, 704, 829, 952   # 中段は半ピッチ右にずれた千鳥配置
$Row3X = 395, 519, 642, 768, 890
$Radius = 58                        # 中心から頂点までの距離(ひし形の半対角線)

$Centers = @()
foreach ($x in $Row1X) { $Centers += ,@($x, 632) }
foreach ($x in $Row2X) { $Centers += ,@($x, 726) }
foreach ($x in $Row3X) { $Centers += ,@($x, 819) }

# 背景透過の輝度しきい値(アイコンの白線画 vs 紫背景/黒枠)
$LumaLow = 140
$LumaHigh = 220

# ひし形右肩の「3本の爪痕」装飾(全アイコン共通の固定位置)を除外する矩形群
# (中心からの相対座標 dx,dy。5種類の異なるアイコンを比較して特定した範囲)
$ClawExclusionBoxes = @(
    @(15, 25, -54, -29),   # 1本目
    @(23, 35, -46, -19),   # 2本目
    @(31, 41, -40, -13)    # 3本目
)

function Test-InClawZone($dx, $dy) {
    foreach ($box in $ClawExclusionBoxes) {
        if ($dx -ge $box[0] -and $dx -le $box[1] -and $dy -ge $box[2] -and $dy -le $box[3]) {
            return $true
        }
    }
    return $false
}

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Get-BitmapBytes($bmp) {
    $rect = New-Object System.Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bytes = New-Object byte[] ($data.Stride * $bmp.Height)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $bmp.UnlockBits($data)
    return @{ Bytes = $bytes; Stride = $data.Stride; Width = $bmp.Width; Height = $bmp.Height }
}

function Test-Purple($r, $g, $b) {
    return (($r - $g) -ge 15 -and ($b - $g) -ge 15 -and $r -lt 180 -and $b -lt 180)
}

function Test-SlotFilled($src, $cx, $cy, $r) {
    $hits = 0
    for ($dy = -$r + 6; $dy -le $r - 6; $dy += 5) {
        for ($dx = -$r + 6; $dx -le $r - 6; $dx += 5) {
            if (([Math]::Abs($dx) + [Math]::Abs($dy)) -gt ($r - 6)) { continue }
            $sx = $cx + $dx; $sy = $cy + $dy
            if ($sx -lt 0 -or $sy -lt 0 -or $sx -ge $src.Width -or $sy -ge $src.Height) { continue }
            $i = $sy * $src.Stride + $sx * 4
            $b = $src.Bytes[$i]; $g = $src.Bytes[$i + 1]; $rr = $src.Bytes[$i + 2]
            if (Test-Purple $rr $g $b) { $hits++ }
            if ($hits -ge 10) { return $true }
        }
    }
    return $false
}

$files = Get-ChildItem -Path $SrcDir -Filter *.jpg | Sort-Object Name
$counter = 1
$totalSaved = 0

foreach ($f in $files) {
    $bmp = [System.Drawing.Bitmap]::FromFile($f.FullName)
    $src = Get-BitmapBytes $bmp
    $bmp.Dispose()

    foreach ($c in $Centers) {
        $cx = $c[0]; $cy = $c[1]
        if (-not (Test-SlotFilled $src $cx $cy $Radius)) { continue }

        $size = $Radius * 2
        $outBytes = New-Object byte[] ($size * $size * 4)

        for ($dy = -$Radius; $dy -lt $Radius; $dy++) {
            for ($dx = -$Radius; $dx -lt $Radius; $dx++) {
                $ox = $dx + $Radius; $oy = $dy + $Radius
                $oi = $oy * $size * 4 + $ox * 4

                $l1 = [Math]::Abs($dx) + [Math]::Abs($dy)
                $sx = $cx + $dx; $sy = $cy + $dy
                if ($l1 -gt $Radius -or $sx -lt 0 -or $sy -lt 0 -or $sx -ge $src.Width -or $sy -ge $src.Height) {
                    continue  # 0で初期化済み = 完全透過
                }

                if (Test-InClawZone $dx $dy) { continue }  # 0で初期化済み = 完全透過

                $si = $sy * $src.Stride + $sx * 4
                $b = $src.Bytes[$si]; $g = $src.Bytes[$si + 1]; $r = $src.Bytes[$si + 2]

                $alpha = 255
                if ($RemoveBackground) {
                    $luma = ($r + $g + $b) / 3.0
                    if ($luma -le $LumaLow) { $alpha = 0 }
                    elseif ($luma -ge $LumaHigh) { $alpha = 255 }
                    else { $alpha = [int](255.0 * ($luma - $LumaLow) / ($LumaHigh - $LumaLow)) }
                }

                $outBytes[$oi] = $b
                $outBytes[$oi + 1] = $g
                $outBytes[$oi + 2] = $r
                $outBytes[$oi + 3] = [byte]$alpha
            }
        }

        $outBmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $outRect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
        $outData = $outBmp.LockBits($outRect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        [System.Runtime.InteropServices.Marshal]::Copy($outBytes, 0, $outData.Scan0, $outBytes.Length)
        $outBmp.UnlockBits($outData)

        $outName = "{0:0000}.png" -f $counter
        $outBmp.Save((Join-Path $OutDir $outName), [System.Drawing.Imaging.ImageFormat]::Png)
        $outBmp.Dispose()

        $counter++
        $totalSaved++
    }
}

Write-Output "完了: $totalSaved 枚のパークアイコンを $OutDir に保存しました。"
