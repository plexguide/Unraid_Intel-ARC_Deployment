# AV1 - Intel ARC Encoding Guide via Unraid + Tdarr Node Scaling/Killer

<h2 align="center">Want to Help? Click the Star in the Upper-Right Corner! ⭐</h2>

**NOTE**  
We’re using `ghcr.io/haveagitgat/tdarr:2.35.02` instead of `ghcr.io/haveagitgat/tdarr:latest`.

**Change Log:**
- **v1:** Original AV1 flow  
- **v2:** Removed B-frames  
- **v3:** Improved quality  
- **v4:** Removed images from files, cutting failure rates from ~25% to 1–2%  
- **v5:** Enhanced quality and simplified workflow 
- **v6:** Added a Special-ish Variable - If file is still to big, try again at a slightly lower quality

<img width="1124" alt="image" src="https://github.com/user-attachments/assets/4956d1d8-8c82-4f9c-95ac-e2df0bc85fb9" />

---

## Introduction

This guide helps you optimize your media library by encoding to AV1 on Unraid while efficiently sharing GPU resources between Plex and Tdarr. You’ll learn how to:

- Set up Intel ARC GPU support on Unraid.  
- Configure Tdarr for AV1 encoding.  
- Manage SABnzbd download speeds based on Plex streams (to prevent buffering).  
- Automatically pause and resume Tdarr when Plex needs the GPU.  

Following these steps will dramatically reduce video file sizes, saving huge amounts of storage, while ensuring Plex always has GPU priority. You’ll also see how to tweak download speeds to avoid streaming slowdowns.

> **Quick Tip:** Always test your AV1 encoding on a small library or a few files. Adjust CRF to balance quality and size before converting your entire collection.

---

## Table of Contents

- [Data Savings with AV1 Encoding](#data-savings-with-av1-encoding)
- [AV1 Drawbacks](#av1-drawbacks)
- [Upgrading to Unraid 7.0 and Installing Required Plugins](#upgrading-to-unraid-70-and-installing-required-plugins)
  - [Installing Intel GPU TOP Plugin](#installing-intel-gpu-top-plugin)
  - [Installing GPU Statistics Plugin](#installing-gpu-statistics-plugin)
- [Deploying Plex with Intel ARC GPU Support](#deploying-plex-with-intel-arc-gpu-support)
  - [Adding the Intel ARC GPU to the Plex Docker Template](#adding-the-intel-arc-gpu-to-the-plex-docker-template)
  - [Configuring Plex Settings](#configuring-plex-settings)
  - [Verifying GPU Transcoding](#verifying-gpu-transcoding)
- [Setting Up Tdarr](#setting-up-tdarr)
  - [Deploying Tdarr Server](#deploying-tdarr-server)
  - [Tdarr Transcoding Location](#tdarr-transcoding-location)
  - [Deploying Tdarr Node(s)](#deploying-tdarr-nodes)
  - [Configuring Tdarr](#configuring-tdarr)
- [Setting up the AV1 Tdarr Flow](#setting-up-the-av1-tdarr-flow)
  - [What is the AV1 Flow?](#what-is-the-av1-flow)
  - [Importing the AV1 Flow in Tdarr](#importing-the-av1-flow-in-tdarr)
- [Setting Up Tdarr Libraries](#setting-up-tdarr-libraries)
- [Optimizing AV1 Encoding Settings](#optimizing-av1-encoding-settings)
- [SABNZBD Speed Control - Bonus](#sabnzbd-speed-control---bonus)
- [Tdarr Node Killer Script](#tdarr-node-killer-script)
  - [Overview](#overview)
  - [Script Behavior](#script-behavior)
  - [Step-by-Step Implementation for Unraid](#step-by-step-implementation-for-unraid)
  - [Script Behavior After Plex Transcoding Stops](#script-behavior-after-plex-transcoding-stops)
  - [Troubleshooting Common Issues](#troubleshooting-common-issues)
- [Experimental: Running the Script on Other Operating Systems](#experimental-running-the-script-on-other-operating-systems)
  - [Step-by-Step Implementation for Other OSes](#step-by-step-implementation-for-other-oses)
- [Backup and Recovery Tips](#backup-and-recovery-tips)
- [Summary](#summary)

---

## Data Savings with AV1 Encoding

AV1 encoding drastically shrinks file sizes. In one example, using three Intel ARC GPUs to encode 10–15% of a large library yielded about **116TB** of savings. For a 300TB media collection, you can potentially reduce it to 75–100TB with careful AV1 conversion.

<img width="373" alt="image" src="https://github.com/user-attachments/assets/09d36726-56d9-4c53-8589-eca2173e7283">

I’ve already saved **255TB** and counting!

---

## AV1 Drawbacks

No codec is perfect. Some devices lack native AV1 decoding, forcing Plex to handle software transcoding. AV1 also requires more resources to encode, which means encoding jobs take longer. For details, check out the [AV1 Drawbacks](https://github.com/plexguide/Unraid_Intel-ARC_Deployment/wiki/AV1-Drawbacks) page.

---

## Upgrading to Unraid 7.0 and Installing Required Plugins

Make sure you’re on Unraid 7.0 or newer, then install the required GPU plugins before using Tdarr or running the Tdarr Node Killer script.

### Installing Intel GPU TOP Plugin

Install **Intel GPU TOP** (by ich777) from Unraid Community Apps to monitor your Intel ARC GPU’s performance directly on Unraid.

![Intel GPU TOP Plugin](https://i.imgur.com/0bHRqya.png)

### Installing GPU Statistics Plugin

Then install **GPU Statistics** (by b3rs3rk). Combined with Intel GPU TOP, it offers detailed GPU usage data during encoding or transcoding.

![GPU Statistics Plugin](https://i.imgur.com/lJZgPvC.png)

After installing both, you’ll see real-time GPU usage:

![GPU Usage Example 1](https://i.imgur.com/toOvgvN.png)  
![GPU Usage Example 2](https://i.imgur.com/jDbrB5a.png)

---

# Deploying Plex with Intel ARC GPU Support

### Adding the Intel ARC GPU to the Plex Docker Template

In your Plex Docker template, add the Intel ARC GPU as a device. Plex won’t see the GPU without this.

![Add Intel ARC GPU to Plex Template](https://i.imgur.com/Da4oeGV.png)

### Configuring Plex Settings

Enable hardware transcoding in Plex and HDR tone mapping (if supported). If your server has multiple GPUs, pick the correct one.

<img width="1020" alt="image" src="https://github.com/user-attachments/assets/2ed05f55-ee92-4011-9f6f-99c24b5d1a3f">

### Verifying GPU Transcoding

Play a video that needs transcoding. On Plex’s dashboard, watch the GPU usage. You should see minimal CPU usage and smooth playback. If you have an AV1 file handy, test it to confirm AV1 transcoding works too!

<img width="286" alt="image" src="https://github.com/user-attachments/assets/e182a603-a7b4-4ae3-b5f0-efbac58b505d" />

---

# Setting Up Tdarr

**What is Tdarr?**  
Tdarr streamlines media transcoding using a friendly GUI, handling conversions for you without complex command lines. At first, it might feel overwhelming, but once you get the hang of it, it’s incredibly powerful for media optimization.

> If you find this guide helpful, please click the ★ (Star) button above. It shows your support and helps others discover this guide.

## Deploying Tdarr Server

You’ll see an option to deploy the server and node in a single container. To simplify troubleshooting, **deploy them separately**:

1. Install **Tdarr** (not Tdarr Node) from the Unraid App Store.  
2. Name it clearly (e.g., “Server” or “TdarrServer”).  
3. Check that the server IP is correct (usually your Unraid server’s IP).  
4. Set **Internal Node** to **False** so you can install a separate node container.

<img width="381" alt="image" src="https://github.com/user-attachments/assets/e3f60be8-5c2b-4ea1-8c36-af7e25097603" />

<img width="557" alt="image" src="https://github.com/user-attachments/assets/126ff9c9-7b32-4fdf-82cc-864bedf85700" />

<img width="688" alt="image" src="https://github.com/user-attachments/assets/b70a2724-b0f7-463e-8da3-c1e7ad3d052b" />

## Tdarr Transcoding Location

Decide where to store transcoded files temporarily. For small workloads, an SSD/NVMe cache is enough. If you plan to transcode heavily (multiple streams, multiple GPUs), consider a dedicated NVMe. Avoid HDDs or RAM to reduce bottlenecks and random errors.

> **Important:** High-volume transcoding quickly wears down SSD/NVMe drives. Many users add a lower-end NVMe just for Tdarr. This preserves your main system drives.

For instance, I use a cheap 512GB NVMe for Tdarr, since Tdarr can easily handle hundreds of terabytes of reads/writes. Doing so keeps my primary NVMe healthier.

<img width="754" alt="image" src="https://github.com/user-attachments/assets/daac629c-3fe9-45e4-89e9-c8e50686e2ea" />

## Deploying Tdarr Node(s)

Once the Tdarr Server is running, install **Tdarr Node** (a separate listing). The server manages libraries and tasks, while the node handles the actual transcoding.

<img width="397" alt="image" src="https://github.com/user-attachments/assets/6b384a42-194d-4089-b1ff-89d6cca77728" />

1. Install **Tdarr Node** from the Unraid App Store.  
2. Name it clearly, like “Node1.” If you have multiple GPUs, install multiple node containers (Node1, Node2, etc.).

<br><img width="477" alt="image" src="https://github.com/user-attachments/assets/8ce39a4d-1479-433c-b3c8-9eceb4ebf044" /><br>

3. Ensure the server IP and node IP match.

<br><img width="749" alt="image" src="https://github.com/user-attachments/assets/736eff11-ec78-441d-9c82-0f11def877bd" /><br>

4. Keep each node’s configs and logs separate.  
5. Match the transcode cache path to the server’s path. If you have more than one node, label them for clarity.  
6. Assign the correct GPU to each node. Don’t overlap GPUs if you have multiple nodes.

<br><img width="769" alt="image" src="https://github.com/user-attachments/assets/b7a2d3e3-288b-4f16-9424-74a82b8f6451" /><br>

**Identify GPUs** by running:
<br><img width="457" alt="image" src="https://github.com/user-attachments/assets/3e8b0028-c1b2-4517-b42d-731c2b01d7f3" /><br>

> **Warning:** One entry might be your iGPU. Don’t assign your iGPU to a Tdarr node.

**Tip:** Go to Plex → Settings → Transcoding. When you pick a GPU in Plex, the GPU order matches the order from `ls -la /dev/dri`. In the example below, `render129` is the iGPU, so I skip it and use `render130` for Node2 and `render131` for Node3.

<br><img width="701" alt="image" src="https://github.com/user-attachments/assets/1dfa28a8-ddd4-4c0b-a1f9-f4ff2b9c5e9b" /><br>

### Configuring Tdarr

1. Go to `http://<your-unraid-IP>:8265`.  
2. You should see your nodes listed:

<br><img width="409" alt="image" src="https://github.com/user-attachments/assets/db6b2dc8-6fb7-4acf-be86-785705a44961" /><br>

3. For each node, click it and set CPU/GPU worker counts based on your ARC card:

    - **ARC 310/380/500/700**  
      - Transcode: CPU (0), GPU (2–4)  
      - Health Check: CPU (2), GPU (0)  

<br><img width="548" alt="image" src="https://github.com/user-attachments/assets/8dc965c7-d801-42b3-af1f-c5310e2e2fad" /><br>

4. Click **Options**, scroll to the bottom, and enable “GPU Workers to do CPU Tasks,” then close.

<br><img width="431" alt="image" src="https://github.com/user-attachments/assets/3cb3786a-025a-48c6-ba72-c6835effef11" /><br>

5. In the staging section, check **Auto-accept successful transcodes** so Tdarr replaces old files automatically.

<br><img width="745" alt="image" src="https://github.com/user-attachments/assets/b78a71c2-71c9-4a01-a5c7-40d34ff26775" /><br>

6. In **Status**, pick the queue order (e.g., largest files first).

<br><img width="774" alt="image" src="https://github.com/user-attachments/assets/111cbddd-bfe3-437f-b79e-7fd00ec90c59" /><br>

---

# Setting up the AV1 Tdarr Flow

**Change Log**  
- **v1:** Original AV1 flow  
- **v2:** Removed B-frames  
- **v3:** Improved quality  
- **v4:** Removed images from files (failure rates ~25% → 1–2%)  
- **v5:** Better quality, simpler flow
- **v6:** Added a retry value if file is still to big

**JSON Script:** [av1_flow_v6.json](av1_flow_v5.json)

<img width="1124" alt="image" src="https://github.com/user-attachments/assets/c543f77c-5b1e-4b35-89d4-ab85444dde15" />

## What is the AV1 Flow?

The AV1 Flow is a prebuilt workflow that encodes your media to AV1 for huge storage savings, without requiring expert knowledge of encoding parameters. You must import it before creating your Tdarr libraries.

## Importing the AV1 Flow in Tdarr

1. In Tdarr, go to **Flows**.  
2. Scroll down and click **Import**.  
3. Paste the AV1 Flow JSON.  
4. Apply it to your libraries.

![Adding a New Flow in Tdarr](https://i.imgur.com/nLzQi1b.png)  
![Scroll to Import Option](https://i.imgur.com/hmYNetQ.png)  
![Pasting the JSON Content](https://i.imgur.com/Qe13kYg.png)

---

# Optimizing AV1 Encoding Settings

Within the AV1 flow, adjust **CRF** and **bitrate** to balance quality and size. Make sure you’ve enabled hardware acceleration so the GPU does the heavy lifting. In general:

- **Higher CRF** → Lower quality, smaller files  
- **Lower CRF** → Higher quality, larger files  

I’ve found the default settings in the AV1 Flow give an excellent quality-to-size ratio. If you want finer control, test small sets of files and tweak CRF/bitrate until you find your sweet spot.

<br><img width="828" alt="image" src="https://github.com/user-attachments/assets/8e5474a0-2601-4d11-a716-4bc3168d6636" /><br>
<br><img width="744" alt="image" src="https://github.com/user-attachments/assets/c53b379a-43e2-4d02-bb10-0e6073b53a66" /><br>

---

# Setting Up Tdarr Libraries

Libraries let you specify locations and define how Tdarr processes them. For instance, you might have separate libraries for “tv” and “movies.” Adjust to your setup.

1. Click **Libraries**:  
<br><img width="646" alt="image" src="https://github.com/user-attachments/assets/2bd6102a-9694-42f1-842d-3cc70f087a0f" /><br>

2. Click **Library+**:
<br><img width="130" alt="image" src="https://github.com/user-attachments/assets/f5c6a119-afb6-4f63-8dbc-c2f1db63c019" /><br>

3. Name your new library (e.g., “TV,” “Movies,” etc.).  
4. Under **Source**, point it to your media folder. Enable [Hourly] scanning to catch new content.

<br><img width="909" alt="image" src="https://github.com/user-attachments/assets/2142aa48-a7a8-4e3f-9dcb-d7df3aed5570" /><br>
<br><img width="292" alt="image" src="https://github.com/user-attachments/assets/e5bb4b33-5115-4d65-a4de-7a28d705a0d0" /><br>

5. Under **Transcode Cache**, set the path to `/temp` (or your chosen transcode folder).

<br><img width="404" alt="image" src="https://github.com/user-attachments/assets/22f9c1f8-a3d8-49a9-8ce6-678c1de28ce4" /><br>

6. In **Filters**, add `AV1` to “Codecs to Skip,” so you never re-encode existing AV1 files. You can also skip small files if you like.

<br><img width="297" alt="image" src="https://github.com/user-attachments/assets/8ed82ff6-aa65-4fbe-a576-39810eeed1c3" /><br>

7. In **Transcode Options**, uncheck “Classic Plugins,” go to the **Flows** tab, and pick the AV1 flow. (If you haven’t imported the flow yet, see the [Importing the AV1 Flow in Tdarr](#importing-the-av1-flow-in-tdarr) section first.)

<br><img width="1004" alt="image" src="https://github.com/user-attachments/assets/a0a4028d-c539-4df9-8e09-4b25a6a2a2a5" /><br>

8. Repeat for all your libraries.  
9. Perform a **Fresh New Scan** to apply changes.

<br><img width="284" alt="image" src="https://github.com/user-attachments/assets/0556d967-8ab3-4628-86d4-12a53a369c0f" /><br>

10. After scanning, the home page should show transcoding activity. If not, re-check your GPU assignments and node settings.

<br><img width="1158" alt="image" src="https://github.com/user-attachments/assets/642f3102-7cfa-4c49-b1d0-0f408930f36d" /><br>

11. If you see tons of errors, review your GPU configuration or flow settings.

<br><img width="1254" alt="image" src="https://github.com/user-attachments/assets/474ce9bf-d883-4b31-afa7-f0ccb909dd0f" /><br>

---

# Tdarr Node Killer Script

**Change Log**  
- **v1:** Original script  
- **v2:** Switched to Tautulli for simpler detection  
- **v3:** Option to avoid killing Tdarr node on local-only transcodes  
- **v4:** Added a threshold to kill the Tdarr container only if transcodes exceed (default) 3 sessions  
- **v5:** Added Tautulli API connectivity check in logs at startup
- **v6:** Added Optional GPU Job Scaling instead of Killing Tdarr Node  

## Overview

The Tdarr Node Killer script ensures Plex always has GPU priority. When Plex starts transcoding on the same GPU, the script stops Tdarr. Once Plex stops, it waits a short cooldown and restarts Tdarr.

## Script Behavior

- Stops the Tdarr Node container as soon as Plex begins GPU transcoding.  
- Waits for Plex transcoding to end, then restarts Tdarr after a short cooldown (e.g., 3 minutes).

**Script (OLD):** [tdarr_node_killer.sh](tdarr_node_killer.sh)
<br>**Script (NEW):** [tdarr_node_scaling.sh](tdarr_node_scaling.sh) - ***Instructions Not Updated Yet***

Use **User Scripts** in Unraid to install this script, set it to run on array startup, and keep it running in the background.

<img width="403" alt="image" src="https://github.com/user-attachments/assets/728a6959-cfaf-44e5-8302-ab43372c87a1">

## Step-by-Step Implementation for Unraid

1. Confirm Tdarr Node the targetted Node is running when no one’s transcoding in Plex:  
   <br><img width="505" alt="image" src="https://github.com/user-attachments/assets/33afaf9e-107e-4b74-9ce2-05cc818d0666" /><br>

2. The script runs and waits for Plex transcoding activity:  
   <br><img width="616" alt="image" src="https://github.com/user-attachments/assets/0e82792a-9164-45b8-8d52-c7c801cb0c82" /><br>

3. A user begins transcoding in Plex:

   <img width="279" alt="image" src="https://github.com/user-attachments/assets/96d6d64c-4dff-440a-89ae-c978d29766f7" />

4A. (Tdarr Scaling) Script detects transcoding threshold set and reduces amount of Tdarr GPU Workers:

   <br><img width="438" alt="image" src="https://github.com/user-attachments/assets/7ed827b3-fd50-4b60-9a59-82be72ada416" /><br>

4B. (Tdarr Killer) Script detects transcoding exceeding set threshold and kills Tdarr Node:

   <br><img width="557" alt="image" src="https://github.com/user-attachments/assets/8efc5c6a-b01a-4b06-8ea2-3b5d15108cab" /><br>
   <br><img width="322" alt="image" src="https://github.com/user-attachments/assets/68dcc0c5-b347-4bed-86cb-53e58637b48b" /><br>

5. Tdarr Node [N1] is now stopped:

   <br><img width="548" alt="image" src="https://github.com/user-attachments/assets/e10fc050-2000-49a6-be46-a49b9a8609e2" /><br>

## Script Behavior After Plex Transcoding Stops

When Plex finishes transcoding, the script waits a cooldown (e.g., 180 seconds) and then restarts Tdarr:

1. You’ll see a countdown timer in the logs before it restarts the container.  
2. Tdarr Node starts again after the countdown:

   <br><img width="611" alt="image" src="https://github.com/user-attachments/assets/7ca1d8b0-efac-44ab-9701-24ef525f33c7"><br>
   <br><img width="323" alt="image" src="https://github.com/user-attachments/assets/9730388b-c5e8-42fc-9392-69b58d9554d7" /><br>

3. Tdarr Node is fully online:

   ![Tdarr Node Online](https://i.imgur.com/M1M2vSL.png)

## Troubleshooting Common Issues

- **Plex Not Using GPU?** Re-check your Plex Docker template and transcoding settings.  
- **Tdarr Not Restarting?** Make sure the script has the right container name, Tautulli API key, and is set to run in the background.  
- **High CPU Usage?** Some features, like HDR tone mapping, can be CPU-intensive. Ensure your GPU and drivers support it. Update drivers if needed.

---

## Experimental: Running the Script on Other Operating Systems

You can run this script on other Linux distributions or OSes that support Docker and systemd. The steps are similar: place the script, set permissions, and create a systemd service.

1. **Save the Script**: Save your Tdarr Node Killer Script as `tdarr_node_killer.sh` in `/usr/local/bin/`.

    ```bash
    sudo nano /usr/local/bin/tdarr_node_killer.sh
    ```

2. **Set the Proper Permissions**:

    ```bash
    sudo chmod +x /usr/local/bin/tdarr_node_killer.sh
    sudo chown root:root /usr/local/bin/tdarr_node_killer.sh
    ```

3. **Create a Service File**: Create a service file for the script:

    ```bash
    sudo nano /etc/systemd/system/tdarr_node_killer.service
    ```

4. **Add the Following Content**:

    ```ini
    [Unit]
    Description=Tdarr Node Killer Script
    After=network.target

    [Service]
    Type=simple
    ExecStart=/bin/bash /usr/local/bin/tdarr_node_killer.sh
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
    ```

5. **Reload Systemd**:

    ```bash
    sudo systemctl daemon-reload
    ```

6. **Start and Enable the Service**:

    ```bash
    sudo systemctl start tdarr_node_killer.service
    sudo systemctl enable tdarr_node_killer.service
    ```

This ensures the script runs automatically and manages your GPU resources even if you’re not on Unraid.

---

## Backup and Recovery Tips

Before making changes:

- Backup Plex configs (metadata, watch history, etc.).
- Backup Docker templates so you can quickly restore containers.
- Backup your Unraid flash drive so you don’t lose your server setup.

Test your backups occasionally to ensure they work when you need them.

---

## Summary

By setting up AV1 encoding with Intel ARC GPUs, you can achieve massive storage savings and still maintain great quality. Adding the optional Tdarr Node Killer Script ensures Plex always has priority access to the GPU when needed. With careful tuning and a bit of experimentation, you can streamline your server’s performance, reduce storage costs, and keep everyone happy with smooth, high-quality streams.

**Found this useful?** Consider clicking the star (★) button at the top!
