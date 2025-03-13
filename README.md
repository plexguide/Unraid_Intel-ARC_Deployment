# AV1 - Intel ARC Encoding Guide via Unraid + Tdarr Node Killer

<h2 align="center">Want to Help? Click the Star in the Upper-Right Corner! ⭐</h2>

**NOTE**  
We’re using `ghcr.io/haveagitgat/tdarr:2.35.02` instead of `ghcr.io/haveagitgat/tdarr:latest`.

**Change Log:**
- **v1:** Original AV1 flow  
- **v2:** Removed B-frames  
- **v3:** Improved quality  
- **v4:** Removed images from files, cutting failure rates from ~25% to 1–2%  
- **v5:** Enhanced quality and simplified workflow  

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
