# Draws the New Intelligence: Battle headquarters illustration (1080x440, the size of vanilla unit illustrations) and the
# "March to the battle" ability icon, and writes them as uncompressed BGRA DDS files with a full mip chain.
# Usage (from the repo root):  powershell -ExecutionPolicy Bypass -File tools\make_hq_art.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$mod = Join-Path $PSScriptRoot '..\mods\new_intelligence_battle\main_menu\gfx\interface'
$preview = Join-Path $PSScriptRoot 'cache\icons_preview'
New-Item -ItemType Directory -Force -Path $preview | Out-Null

$code = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Collections.Generic;

public static class CwArt
{
    static Random rnd = new Random(1337);

    static Color C(int r, int g, int b) { return Color.FromArgb(255, r, g, b); }
    static Color C(int a, int r, int g, int b) { return Color.FromArgb(a, r, g, b); }

    static PointF[] Ridge(int w, float baseY, float amp, int seed, int steps)
    {
        var r = new Random(seed);
        var pts = new List<PointF>();
        float y = baseY;
        for (int i = 0; i <= steps; i++)
        {
            float x = w * i / (float)steps;
            y = baseY + (float)(Math.Sin(i * 0.37 + seed) * amp * 0.6 + Math.Sin(i * 0.11 + seed * 2) * amp + (r.NextDouble() - 0.5) * amp * 0.5);
            pts.Add(new PointF(x, y));
        }
        pts.Add(new PointF(w, 2000)); pts.Add(new PointF(0, 2000));
        return pts.ToArray();
    }

    static void Tent(Graphics g, float cx, float baseY, float w, float h, Color a, Color b, bool stripes)
    {
        var body = new PointF[] { new PointF(cx - w / 2, baseY), new PointF(cx, baseY - h), new PointF(cx + w / 2, baseY) };
        using (var br = new LinearGradientBrush(new PointF(cx - w / 2, 0), new PointF(cx + w / 2, 0), a, b)) g.FillPolygon(br, body);
        if (stripes)
        {
            using (var p = new Pen(C(120, 120, 20, 20), w / 18))
                for (int i = -3; i <= 3; i++) g.DrawLine(p, cx, baseY - h, cx + i * w / 7.0f, baseY);
        }
        using (var p = new Pen(C(160, 30, 20, 12), 2)) g.DrawPolygon(p, body);
    }

    static void Figure(Graphics g, float x, float y, float s, Color body, Color rim, bool hat, int pose)
    {
        // y = feet; s = height
        using (var b = new SolidBrush(body))
        using (var rp = new Pen(rim, Math.Max(1.5f, s / 60)))
        {
            float head = s * 0.11f;
            var torso = new PointF[] {
                new PointF(x - s * 0.13f, y - s * 0.78f), new PointF(x + s * 0.13f, y - s * 0.78f),
                new PointF(x + s * 0.17f, y - s * 0.40f), new PointF(x + s * 0.20f, y - s * 0.05f),
                new PointF(x - s * 0.20f, y - s * 0.05f), new PointF(x - s * 0.17f, y - s * 0.40f) };
            g.FillPolygon(b, torso);
            g.FillRectangle(b, x - s * 0.12f, y - s * 0.08f, s * 0.09f, s * 0.08f);
            g.FillRectangle(b, x + s * 0.03f, y - s * 0.08f, s * 0.09f, s * 0.08f);
            g.FillEllipse(b, x - head / 2, y - s * 0.78f - head * 1.05f, head, head * 1.1f);
            if (hat)
            {
                g.FillEllipse(b, x - head * 1.1f, y - s * 0.78f - head * 1.25f, head * 2.2f, head * 0.55f);
                g.FillEllipse(b, x - head * 0.55f, y - s * 0.78f - head * 1.75f, head * 1.1f, head * 0.8f);
                using (var plume = new SolidBrush(C(230, 190, 60, 40)))
                    g.FillEllipse(plume, x + head * 0.2f, y - s * 0.78f - head * 2.1f, head * 0.9f, head * 0.5f);
            }
            // arms
            using (var ap = new Pen(body, s * 0.07f) { StartCap = LineCap.Round, EndCap = LineCap.Round })
            {
                if (pose == 1) g.DrawLine(ap, x + s * 0.12f, y - s * 0.70f, x + s * 0.42f, y - s * 0.58f);      // pointing
                else g.DrawLine(ap, x + s * 0.12f, y - s * 0.70f, x + s * 0.18f, y - s * 0.40f);
                if (pose == 2) g.DrawLine(ap, x - s * 0.12f, y - s * 0.70f, x - s * 0.30f, y - s * 0.55f);   // hand on table
                else g.DrawLine(ap, x - s * 0.12f, y - s * 0.70f, x - s * 0.18f, y - s * 0.40f);
            }
            // rim light on the lit side (right)
            g.DrawLine(rp, x + s * 0.13f, y - s * 0.78f, x + s * 0.20f, y - s * 0.05f);
            // sash
            using (var sash = new Pen(C(200, 170, 40, 35), s * 0.035f))
                g.DrawLine(sash, x - s * 0.12f, y - s * 0.74f, x + s * 0.17f, y - s * 0.42f);
        }
    }

    static void Glow(Graphics g, float x, float y, float r, Color c)
    {
        using (var path = new GraphicsPath())
        {
            path.AddEllipse(x - r, y - r, 2 * r, 2 * r);
            using (var br = new PathGradientBrush(path))
            {
                br.CenterColor = c;
                br.SurroundColors = new Color[] { Color.FromArgb(0, c.R, c.G, c.B) };
                g.FillEllipse(br, x - r, y - r, 2 * r, 2 * r);
            }
        }
    }

    public static Bitmap DrawHq(int w, int h)
    {
        var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            // sky
            using (var sky = new LinearGradientBrush(new Point(0, 0), new Point(0, (int)(h * 0.72)), C(38, 52, 74), C(222, 160, 92)))
                g.FillRectangle(sky, 0, 0, w, h);
            Glow(g, w * 0.78f, h * 0.60f, h * 0.9f, C(150, 255, 196, 120));
            Glow(g, w * 0.78f, h * 0.62f, h * 0.18f, C(230, 255, 230, 170));
            // clouds
            var cr = new Random(7);
            for (int i = 0; i < 14; i++)
            {
                float cx = (float)(cr.NextDouble() * w), cy = (float)(h * (0.12 + cr.NextDouble() * 0.28));
                float cw = (float)(160 + cr.NextDouble() * 260), ch = (float)(14 + cr.NextDouble() * 22);
                using (var b = new SolidBrush(C(55, 250, 220, 190))) g.FillEllipse(b, cx - cw / 2, cy - ch / 2, cw, ch);
            }
            // far hills, near hills
            using (var b = new SolidBrush(C(96, 104, 124))) g.FillPolygon(b, Ridge(w, h * 0.56f, 22, 3, 60));
            using (var b = new SolidBrush(C(70, 74, 82))) g.FillPolygon(b, Ridge(w, h * 0.64f, 16, 11, 80));
            // ground
            using (var gr = new LinearGradientBrush(new Point(0, (int)(h * 0.66)), new Point(0, h), C(74, 70, 46), C(30, 28, 20)))
                g.FillRectangle(gr, 0, (int)(h * 0.66), w, h);
            using (var b = new SolidBrush(C(58, 56, 38))) g.FillPolygon(b, Ridge(w, h * 0.70f, 6, 21, 60));
            // distant camp: small tents and smoke
            var tr = new Random(5);
            for (int i = 0; i < 18; i++)
            {
                float tx = (float)(w * 0.48 + tr.NextDouble() * w * 0.5), ty = (float)(h * (0.69 + tr.NextDouble() * 0.04));
                float tw = (float)(22 + tr.NextDouble() * 18);
                Tent(g, tx, ty, tw, tw * 0.75f, C(170, 156, 128), C(120, 108, 88), false);
            }
            for (int i = 0; i < 4; i++)
            {
                float sx = (float)(w * 0.55 + i * w * 0.1), sy = h * 0.66f;
                for (int k = 0; k < 6; k++)
                    using (var b = new SolidBrush(C(28 - k * 4, 210, 200, 190)))
                        g.FillEllipse(b, sx + k * 6 - 10, sy - k * 18 - 20, 26 + k * 6, 18 + k * 4);
            }
            // the command tent
            float tcx = w * 0.30f, tby = h * 0.86f;
            Tent(g, tcx, tby, w * 0.36f, h * 0.50f, C(196, 52, 40), C(110, 26, 22), true);
            // open entrance with warm light
            var door = new PointF[] { new PointF(tcx - w * 0.05f, tby), new PointF(tcx, tby - h * 0.30f), new PointF(tcx + w * 0.05f, tby) };
            using (var b = new SolidBrush(C(255, 196, 110))) g.FillPolygon(b, door);
            Glow(g, tcx, tby - h * 0.08f, h * 0.25f, C(110, 255, 190, 110));
            // guy ropes of the tent
            using (var p = new Pen(C(120, 40, 30, 20), 2))
            {
                g.DrawLine(p, tcx - w * 0.12f, tby - h * 0.17f, tcx - w * 0.22f, tby);
                g.DrawLine(p, tcx + w * 0.12f, tby - h * 0.17f, tcx + w * 0.22f, tby);
            }
            // flagpole with the HQ banner (red, gold star) and pennants
            using (var p = new Pen(C(60, 44, 28), 6)) g.DrawLine(p, tcx, tby - h * 0.50f, tcx, tby - h * 0.84f);
            var flag = new PointF[] { new PointF(tcx + 3, tby - h * 0.83f), new PointF(tcx + w * 0.13f, tby - h * 0.80f), new PointF(tcx + w * 0.10f, tby - h * 0.73f), new PointF(tcx + w * 0.13f, tby - h * 0.66f), new PointF(tcx + 3, tby - h * 0.68f) };
            using (var b = new SolidBrush(C(170, 30, 26))) g.FillPolygon(b, flag);
            using (var p = new Pen(C(230, 190, 90), 3)) g.DrawPolygon(p, flag);
            Star(g, tcx + w * 0.055f, tby - h * 0.745f, h * 0.045f, C(240, 200, 90));
            using (var b = new SolidBrush(C(230, 190, 90))) g.FillEllipse(b, tcx - 7, tby - h * 0.86f, 14, 14);
            foreach (float px in new float[] { -0.16f, 0.16f })
            {
                float bx = tcx + w * px;
                using (var p = new Pen(C(60, 44, 28), 3)) g.DrawLine(p, bx, tby - h * 0.02f, bx, tby - h * 0.36f);
                var pen = new PointF[] { new PointF(bx, tby - h * 0.36f), new PointF(bx + 40, tby - h * 0.33f), new PointF(bx, tby - h * 0.30f) };
                using (var b = new SolidBrush(C(230, 190, 90))) g.FillPolygon(b, pen);
            }
            // torches
            foreach (float px in new float[] { 0.47f, 0.70f })
            {
                float bx = w * px, by = h * 0.90f;
                using (var p = new Pen(C(50, 36, 22), 5)) g.DrawLine(p, bx, by, bx, by - h * 0.22f);
                Glow(g, bx, by - h * 0.24f, h * 0.16f, C(140, 255, 170, 70));
                using (var b = new SolidBrush(C(255, 220, 120))) g.FillEllipse(b, bx - 6, by - h * 0.27f, 12, 18);
            }
            // field table with the campaign map
            float tx0 = w * 0.50f, ty0 = h * 0.77f, tw0 = w * 0.18f, th0 = h * 0.07f;
            using (var b = new SolidBrush(C(70, 46, 28))) g.FillRectangle(b, tx0, ty0, tw0, th0 * 0.4f);
            using (var p = new Pen(C(55, 36, 22), 6)) { g.DrawLine(p, tx0 + 8, ty0, tx0 + 8, h * 0.93f); g.DrawLine(p, tx0 + tw0 - 8, ty0, tx0 + tw0 - 8, h * 0.93f); }
            var map = new PointF[] { new PointF(tx0 + 6, ty0 - 2), new PointF(tx0 + tw0 - 4, ty0 - 4), new PointF(tx0 + tw0 - 10, ty0 + 6), new PointF(tx0 + 10, ty0 + 8) };
            using (var b = new SolidBrush(C(232, 214, 168))) g.FillPolygon(b, map);
            using (var p = new Pen(C(150, 120, 40, 30), 2))
            {
                g.DrawBezier(p, tx0 + 20, ty0 + 2, tx0 + 60, ty0 - 4, tx0 + 90, ty0 + 6, tx0 + tw0 - 30, ty0);
                g.DrawLine(p, tx0 + 60, ty0 - 2, tx0 + 75, ty0 + 5);
            }
            using (var b = new SolidBrush(C(160, 30, 26))) g.FillEllipse(b, tx0 + tw0 * 0.55f, ty0 - 2, 8, 6);
            Glow(g, tx0 + tw0 * 0.8f, ty0 - 12, 30, C(150, 255, 210, 120));
            using (var b = new SolidBrush(C(250, 240, 200))) g.FillRectangle(b, tx0 + tw0 * 0.8f - 3, ty0 - 16, 6, 14);
            // officers around the table, a guard with a halberd at the tent
            Color sil = C(26, 22, 20), rim = C(230, 255, 190, 110);
            Figure(g, tx0 - w * 0.025f, h * 0.95f, h * 0.36f, sil, rim, true, 1);
            Figure(g, tx0 + tw0 * 0.45f, h * 0.93f, h * 0.30f, C(34, 30, 28), rim, true, 2);
            Figure(g, tx0 + tw0 + w * 0.02f, h * 0.96f, h * 0.34f, sil, rim, false, 2);
            Figure(g, tcx - w * 0.09f, h * 0.97f, h * 0.38f, sil, rim, true, 0);
            using (var p = new Pen(C(40, 34, 30), 4)) g.DrawLine(p, tcx - w * 0.06f, h * 0.97f, tcx - w * 0.06f, h * 0.47f);
            var blade = new PointF[] { new PointF(tcx - w * 0.06f, h * 0.47f), new PointF(tcx - w * 0.06f + 16, h * 0.51f), new PointF(tcx - w * 0.06f, h * 0.55f) };
            using (var b = new SolidBrush(C(190, 196, 204))) g.FillPolygon(b, blade);
            // foreground grass shadow
            using (var gr = new LinearGradientBrush(new Point(0, (int)(h * 0.9)), new Point(0, h), C(0, 0, 0, 0), C(140, 10, 8, 4)))
                g.FillRectangle(gr, 0, (int)(h * 0.9), w, (int)(h * 0.1) + 1);
        }
        Grain(bmp, 10);
        Vignette(bmp);
        return bmp;
    }

    static void Star(Graphics g, float cx, float cy, float r, Color c)
    {
        var pts = new PointF[10];
        for (int i = 0; i < 10; i++)
        {
            double a = -Math.PI / 2 + i * Math.PI / 5; float rr = (i % 2 == 0) ? r : r * 0.42f;
            pts[i] = new PointF(cx + rr * (float)Math.Cos(a), cy + rr * (float)Math.Sin(a));
        }
        using (var b = new SolidBrush(c)) g.FillPolygon(b, pts);
    }

    static void Grain(Bitmap bmp, int amount)
    {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var d = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        var buf = new byte[d.Stride * bmp.Height];
        System.Runtime.InteropServices.Marshal.Copy(d.Scan0, buf, 0, buf.Length);
        var r = new Random(99);
        for (int i = 0; i < buf.Length; i += 4)
        {
            int n = r.Next(-amount, amount + 1);
            for (int k = 0; k < 3; k++) buf[i + k] = (byte)Math.Max(0, Math.Min(255, buf[i + k] + n));
        }
        System.Runtime.InteropServices.Marshal.Copy(buf, 0, d.Scan0, buf.Length);
        bmp.UnlockBits(d);
    }

    static void Vignette(Bitmap bmp)
    {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var d = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        var buf = new byte[d.Stride * bmp.Height];
        System.Runtime.InteropServices.Marshal.Copy(d.Scan0, buf, 0, buf.Length);
        double cx = bmp.Width / 2.0, cy = bmp.Height / 2.0;
        for (int y = 0; y < bmp.Height; y++)
            for (int x = 0; x < bmp.Width; x++)
            {
                double dx = (x - cx) / cx, dy = (y - cy) / cy;
                double f = 1.0 - 0.35 * Math.Min(1.0, (dx * dx * 0.7 + dy * dy * 0.5));
                int i = y * d.Stride + x * 4;
                for (int k = 0; k < 3; k++) buf[i + k] = (byte)(buf[i + k] * f);
            }
        System.Runtime.InteropServices.Marshal.Copy(buf, 0, d.Scan0, buf.Length);
        bmp.UnlockBits(d);
    }

    public static Bitmap DrawMarchIcon(int size)
    {
        var big = new Bitmap(256, 256, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(big))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            Color gold = C(222, 184, 92), ink = C(34, 24, 16), steel = C(226, 228, 232), red = C(150, 32, 28);
            using (var b = new SolidBrush(C(200, 28, 20, 14))) g.FillEllipse(b, 14, 14, 228, 228);
            using (var p = new Pen(gold, 8)) g.DrawEllipse(p, 14, 14, 228, 228);
            // crossed swords
            foreach (int sgn in new int[] { -1, 1 })
            {
                var m = new Matrix(); m.RotateAt(sgn * 40, new PointF(128, 120)); g.Transform = m;
                var blade = new PointF[] { new PointF(122, 40), new PointF(134, 40), new PointF(134, 150), new PointF(128, 162), new PointF(122, 150) };
                using (var b = new SolidBrush(steel)) g.FillPolygon(b, blade);
                using (var p = new Pen(ink, 3)) g.DrawPolygon(p, blade);
                using (var p = new Pen(gold, 10) { StartCap = LineCap.Round, EndCap = LineCap.Round }) g.DrawLine(p, 104, 150, 152, 150);
                using (var p = new Pen(C(120, 86, 30), 12) { StartCap = LineCap.Round, EndCap = LineCap.Round }) g.DrawLine(p, 128, 156, 128, 186);
                g.ResetTransform();
            }
            // forward arrow (the march)
            var arrow = new PointF[] { new PointF(58, 196), new PointF(160, 196), new PointF(160, 180), new PointF(200, 206), new PointF(160, 232), new PointF(160, 216), new PointF(58, 216) };
            using (var b = new SolidBrush(red)) g.FillPolygon(b, arrow);
            using (var p = new Pen(gold, 4)) g.DrawPolygon(p, arrow);
        }
        var outb = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (var g2 = Graphics.FromImage(outb))
        {
            g2.InterpolationMode = InterpolationMode.HighQualityBicubic; g2.PixelOffsetMode = PixelOffsetMode.HighQuality; g2.CompositingMode = CompositingMode.SourceCopy;
            g2.DrawImage(big, 0, 0, size, size);
        }
        big.Dispose();
        return outb;
    }

    // Uncompressed 32-bit BGRA DDS with a full mip chain (each level = floor(previous / 2), at least 1).
    public static void WriteDds(Bitmap top, string path)
    {
        var levels = new List<byte[]>();
        Bitmap cur = top; int w = top.Width, h = top.Height;
        while (true)
        {
            var d = cur.LockBits(new Rectangle(0, 0, cur.Width, cur.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var bytes = new byte[cur.Width * cur.Height * 4];
            for (int y = 0; y < cur.Height; y++)
                System.Runtime.InteropServices.Marshal.Copy(new IntPtr(d.Scan0.ToInt64() + (long)y * d.Stride), bytes, y * cur.Width * 4, cur.Width * 4);
            cur.UnlockBits(d);
            levels.Add(bytes);
            if (cur.Width == 1 && cur.Height == 1) break;
            int nw = Math.Max(1, cur.Width / 2), nh = Math.Max(1, cur.Height / 2);
            var next = new Bitmap(nw, nh, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(next))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality; g.CompositingMode = CompositingMode.SourceCopy;
                g.DrawImage(cur, 0, 0, nw, nh);
            }
            if (cur != top) cur.Dispose();
            cur = next;
        }
        using (var fs = File.Create(path))
        using (var bw = new BinaryWriter(fs))
        {
            bw.Write(new byte[] { (byte)'D', (byte)'D', (byte)'S', (byte)' ' });
            bw.Write(124u); bw.Write(0x2100Fu); bw.Write((uint)h); bw.Write((uint)w);
            bw.Write((uint)(w * 4)); bw.Write(0u); bw.Write((uint)levels.Count);
            for (int i = 0; i < 11; i++) bw.Write(0u);
            bw.Write(32u); bw.Write(0x41u); bw.Write(0u); bw.Write(32u);
            bw.Write(0x00FF0000u); bw.Write(0x0000FF00u); bw.Write(0x000000FFu); bw.Write(0xFF000000u);
            bw.Write(0x401008u); bw.Write(0u); bw.Write(0u); bw.Write(0u); bw.Write(0u);
            foreach (var l in levels) bw.Write(l);
        }
    }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

$art = [CwArt]::DrawHq(1080, 440)
$artPath = Join-Path $mod 'illustrations\units\cw_army_headquarters.dds'
New-Item -ItemType Directory -Force -Path (Split-Path $artPath) | Out-Null
[CwArt]::WriteDds($art, $artPath)
$art.Save((Join-Path $preview 'cw_army_headquarters_illustration.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$art.Dispose()
Write-Output ("{0} {1} bytes" -f $artPath, (Get-Item $artPath).Length)

$icon = [CwArt]::DrawMarchIcon(128)
$iconPath = Join-Path $mod 'icons\unit_ability\cw_march_to_battle.dds'
New-Item -ItemType Directory -Force -Path (Split-Path $iconPath) | Out-Null
[CwArt]::WriteDds($icon, $iconPath)
$icon.Save((Join-Path $preview 'cw_march_to_battle.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$icon.Dispose()
Write-Output ("{0} {1} bytes" -f $iconPath, (Get-Item $iconPath).Length)
