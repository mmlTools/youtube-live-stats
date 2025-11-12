# YouTube Live Stats (OBS Lua)

Fetches YouTube stats and updates **3 Text sources** (GDI+ / FreeType 2) in OBS Studio.  
No popups. Cross‑platform (Windows, macOS, Linux).

- ⬇️ **Download the script:** [`Youtube Live Stats.lua`](src/Youtube Live Stats.lua)
- ☕ **Support:** [Ko‑fi](https://ko-fi.com/mmltech) • [PayPal](https://paypal.me/mmltools)

---

## Quick Start

1. Open **Tools → Scripts** in OBS and add `Youtube Live Stats.lua`.
2. Create or type in three Text source names for **Likes**, **Views**, and **Viewers**.
3. Enter your **YouTube Video ID** and **API Key**.
4. Click **🔄 Refresh and create sources** then **🎨 Apply Formatting**.

> **Tip:** Learn how to get a free YouTube API key:  
> https://obscountdown.com/youtube-live-likes-counter-obs-studio#tutorial

**Screenshot**  
![OBS → Tools → Scripts — load the Lua file](docs/assets/img/Screenshot_5.png "OBS → Tools → Scripts — load the Lua file")

---

## Install

### OBS Steps (All platforms)

1. Open **Tools → Scripts** in OBS Studio.
2. Click the **＋ Add** button and select `Youtube Live Stats.lua`.
3. The script appears in the list; select it to configure.

> **Recommended:** Store the Lua file in a dedicated folder so it doesn’t get lost when cleaning project files.

### Preferred location (create `obs-scripts`)

- **Windows:** `%AppData%\obs-studio\obs-scripts\`
- **macOS:** `~/Library/Application Support/obs-studio/obs-scripts/`
- **Linux:** `~/.config/obs-studio/obs-scripts/`

**Example layout**

```text
obs-studio/
└─ obs-scripts/
   └─ Youtube Live Stats.lua
```

**Screenshots**

- Open **Tools → Scripts**  
  ![Open the Scripts window in OBS](docs/assets/img/Screenshot_2.png "Open the Scripts window in OBS")

- Press **＋ Add** and load the Lua file from your `obs-scripts` folder.  
  ![Load the Lua script with the + button](docs/assets/img/Screenshot_3.png "Load the Lua script with the + button")

---

## Configure

| Field                              | Description                                                  |
| ---------------------------------- | ------------------------------------------------------------ |
| **YouTube Video ID**               | ID of the live video whose stats you want.                   |
| **YouTube API Key**                | Your YouTube Data API v3 key.                                |
| **Polling interval (s)**           | How often to refresh stats (min 5s).                         |
| **Likes / Views / Viewers Source** | OBS Text sources to receive values.                          |
| **Font / Color**                   | Optional: set consistent visual style for all three sources. |

**Screenshot**  
![Script properties with sources, API key, and formatting](docs/assets/img/Screenshot_4.png "Script properties with sources, API key, and formatting")

---

## How It Works

The script queries the YouTube Data API for `statistics` and `liveStreamingDetails`.  
It updates three text sources with **Likes**, **Views**, and **concurrent live Viewers**.  
If a source is missing, the script can **create it automatically** and add it to your active scene.

---

## Troubleshooting

- **Empty values**: If the stream isn’t live, `concurrentViewers` may be `-`.
- **No updates**: Verify Video ID / API key; ensure **Polling interval ≥ 5s**.
- **Sources missing**: Click **Refresh and create sources** and re‑select them.

---

## FAQ

**Q.** Does it run on all platforms?  
**A.** Yes — Windows, macOS, and Linux.

**Q.** Can I change fonts/colors later?  
**A.** Yes — adjust the font and color picker and click **🎨 Apply Formatting**.

**Q.** Where do I get the API key?  
**A.** See the tutorial on https://obscountdown.com/youtube-live-likes-counter-obs-studio#tutorial

---

## Credits

Powered by **obscountdown.com**  
Author: **MMLTech** — [Ko‑fi](https://ko-fi.com/mmltech) • [PayPal](https://paypal.me/mmltools)
