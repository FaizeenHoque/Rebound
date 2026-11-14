#!/usr/bin/env python3
"""Downloads and processes RE:BOUND's meme sound effects.

Clips come from myinstants.com. They are NOT clearly licensed.
Each clip is: leading silence removed -> trimmed to the
slot's max length -> faded out -> loudness-normalised -> mono 44.1 kHz OGG.

Run: python3 tools/fetch_meme_sfx.py [download_dir] [slot ...]   (default: every slot)
Needs: ffmpeg + ffprobe on PATH.
"""
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

BASE = "https://www.myinstants.com/media/sounds/"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "meme")
UA = "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/130.0"

# slot -> list of (myinstants file, max seconds, extra ffmpeg filter or "")
# Each list entry becomes <slot>_<index>.ogg; the game picks randomly per pool.
MANIFEST = {
    "death": [
        ("metal-pipe-falling-sound-effect.mp3", 2.0, ""),
        ("bruh-sound-effect_WstdzdM.mp3", 1.5, ""),
        ("emotional-damage-meme.mp3", 2.0, ""),
        ("og-roblox-death-sound-effect-uhh-oof.mp3", 1.2, ""),
        ("windows-xp-critical-error-full-version.mp3", 1.6, ""),
        ("mission-failed-well-get-em-next-time-sound-effect-zxhixnbk.mp3", 2.8, ""),
    ],
    "rebound": [("yeet-sound-effect.mp3", 1.0, "")],
    "echo": [("gta-san-andreas-ah-shit-here-we-go-again.mp3", 2.5, "")],
    "respawn": [("cartoon-boing.mp3", 0.8, "asetrate=44100*1.25,aresample=44100")],
    "bounce": [("cartoon-boing.mp3", 0.8, "")],
    "jump": [("boing-cartoon-effect.mp3", 0.3, "")],
    "land": [("vine-boom.mp3", 1.0, "")],
    "plate_on": [("click-nice.mp3", 1.5, "")],
    "plate_off": [("calebcity-nope-sound.mp3", 1.0, "")],
    "door_open": [("angelchoirmarktreekort.mp3", 1.5, "")],
    "door_close": [("bruh-sound-effect_WstdzdM.mp3", 1.0, "")],
    "complete": [
        ("mlg-air-horn-sound.mp3", 2.5, ""),
        ("owen-wilson-wow-8.mp3", 2.0, ""),
    ],
    "select": [("bubble-pop.mp3", 0.2, "")],
    # flying enemies: chatter while they fly, bonk when stomped, mock when they get you
    "flyer_chatter": [
        ("cat-meow_Li0Ycr1.mp3", 1.0, ""),
        ("deep-meow_Wt1vUzN.mp3", 1.2, ""),
        ("huh-cat-meme.mp3", 1.2, ""),
        ("pop-cat-original-meme.mp3", 0.8, ""),
        ("cat-mouth-noise-192-kbps.mp3", 0.6, ""),
        ("0045-nyan.mp3", 1.2, ""),
        ("anime-wow-sound-effect.mp3", 1.2, ""),
    ],
    "flyer_pop": [
        ("bonk-doge-sfx.mp3", 1.0, ""),
        ("bamboo-hit-anime-bonk-sound.mp3", 1.0, ""),
        ("big-head-bonk-sound-effect-low-pitched.mp3", 1.0, ""),
        ("bonk-and-cymbal.mp3", 1.2, ""),
    ],
    # pixel-cat-meme-3 (the screaming cat) snores instead of meowing
    "snore": [("hoooo-snoring.mp3", 2.0, "")],
    "flyer_kill": [
        ("frankly-thats-a-skill-issue.mp3", 2.5, ""),
        ("halo-announcer-skill-issue.mp3", 2.0, ""),
        ("capone-oh-no_JSNHmad.mp3", 2.0, ""),
        ("oh-hell-no_aQX7VTp.mp3", 2.0, ""),
        ("among-us-dead-body-reported-sound-effect_BsczDVE.mp3", 2.5, ""),
    ],
}


def download(name, dl_dir):
    path = os.path.join(dl_dir, name)
    for attempt in range(5):
        if os.path.exists(path):
            break
        try:
            req = urllib.request.Request(BASE + name, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read()
            with open(path, "wb") as f:
                f.write(data)
        except OSError:
            time.sleep(2 + attempt * 2)  # the site resets connections under load
    if not os.path.exists(path):
        raise RuntimeError(f"could not download {name}")
    return path


def duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
        capture_output=True, text=True, check=True)
    return float(out.stdout.strip())


def process(src, dst, max_len, extra, work_dir):
    trimmed = os.path.join(work_dir, os.path.basename(dst) + ".trim.wav")
    pre = "silenceremove=start_periods=1:start_threshold=-45dB"
    if extra:
        pre += "," + extra
    pre += f",atrim=0:{max_len}"
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-af", pre, "-ac", "1", trimmed], check=True)
    d = duration(trimmed)
    fade = min(0.08, d * 0.3)
    post = f"afade=t=out:st={max(d - fade, 0):.3f}:d={fade:.3f},loudnorm=I=-16:TP=-1.5:LRA=11"
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", trimmed, "-af", post,
                    "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
    return duration(dst)


def main():
    dl_dir = sys.argv[1] if len(sys.argv) > 1 else tempfile.mkdtemp(prefix="meme_sfx_")
    os.makedirs(dl_dir, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[2:])
    for slot, clips in MANIFEST.items():
        if only and slot not in only:
            continue
        for i, (name, max_len, extra) in enumerate(clips):
            src = download(name, dl_dir)
            dst = os.path.join(OUT, f"{slot}_{i}.ogg")
            d = process(src, dst, max_len, extra, dl_dir)
            print(f"{slot}_{i}.ogg  {d:5.2f}s  <- {name} (source {duration(src):.2f}s)")


if __name__ == "__main__":
    main()
