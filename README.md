# Guide to Intel ARC AV1 Encoding on Unraid + Tdarr Node Killer + SAB Speed Control (Bonus)

**Want to help?** Click the ★ (Star) button in the upper-right corner!

This guide shows you how to optimize your media library with AV1 encoding on Unraid, while also managing GPU resources between Plex and Tdarr. You’ll learn how to shrink your video files, save a ton of storage space, and automatically free up your GPU for Plex users. On top of that, we’ll show you how to use a simple script to pause Tdarr when Plex needs the GPU, then restart Tdarr when Plex is done.

**This guide covers:**
- Getting your Intel ARC GPU set up on Unraid.
  - Setting up Tdarr (working on)   
  - Encoding videos to AV1 for huge space savings.
- SABNZBD Speed Control (Priotize SAB download speeds when users watch PLEX, including night control speeds)
- Tdarr Node Killer (Priotize Plex for your GPU if PLEX and the Tdarr Node share the same GPU)

Whether you’re an Unraid pro or new to the platform, we’ll walk you through it step-by-step.

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
- [AV1 Tdarr Flow](#av1-tdarr-flow)
  - [What is the AV1 Flow?](#what-is-the-av1-flow)
  - [Importing the AV1 Flow in Tdarr](#importing-the-av1-flow-in-tdarr)
- [Optimizing AV1 Encoding Settings](#optimizing-av1-encoding-settings)
- [SABNZBD Speed Control - Bonus](#sabnzbd-speed-control)
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

With AV1, you can drastically reduce storage usage. In tests with three Intel ARC GPUs, just encoding 10-15% of a large library saved about 37TB! For a 300TB collection, AV1 could potentially bring it down to 75-100TB.

<img width="373" alt="image" src="https://github.com/user-attachments/assets/09d36726-56d9-4c53-8589-eca2173e7283">

In short, AV1 can save you tons of space and costs.

---

## AV1 Drawbacks

AV1 isn’t perfect. Some devices can’t handle it natively yet, and the encoding process might be slower or more resource-intensive. For more details, check out the [AV1 Drawbacks](https://github.com/plexguide/Unraid_Intel-ARC_Deployment/wiki/AV1-Drawbacks) page.

---

## Upgrading to Unraid 7.0 and Installing Required Plugins

Before setting up AV1 flows or using the Tdarr Node Killer Script, make sure you’re on Unraid 7.0 (or newer) and have the proper plugins to manage and monitor your Intel ARC GPU.

### Installing Intel GPU TOP Plugin

Install **Intel GPU TOP** by ich777 from the Unraid Community Apps. This lets you monitor your Intel ARC GPU’s performance directly in Unraid.

![Intel GPU TOP Plugin](https://i.imgur.com/0bHRqya.png)

### Installing GPU Statistics Plugin

Install the **GPU Statistics** plugin by b3rs3rk for detailed GPU usage stats. With these two plugins, you’ll easily confirm that your GPU is being used when encoding or transcoding.

![GPU Statistics Plugin](https://i.imgur.com/lJZgPvC.png)

Once installed, you can see real-time GPU usage:

![GPU in Use Example 1](https://i.imgur.com/toOvgvN.png)

![GPU in Use Example 2](https://i.imgur.com/jDbrB5a.png)

---

# Deploying Plex with Intel ARC GPU Support

### Adding the Intel ARC GPU to the Plex Docker Template

In your Plex Docker template, add the Intel ARC GPU as a device. Without this, Plex won’t know it can use your GPU.

![Add Intel ARC GPU to Plex Template](https://i.imgur.com/Da4oeGV.png)

### Configuring Plex Settings

Enable GPU transcoding in Plex and, if needed, HDR tone mapping. If you have multiple identical GPUs, Plex lists them in order. Make sure you select the correct one.

<img width="1020" alt="image" src="https://github.com/user-attachments/assets/2ed05f55-ee92-4011-9f6f-99c24b5d1a3f">

### Verifying GPU Transcoding

Play a file that needs transcoding. Check Plex’s dashboard and GPU stats. If the GPU is doing the work, you’ll see less CPU usage and a smooth playback experience.

![Plex Transcoding with Intel ARC GPU](https://i.imgur.com/Zz9jfYo.png)

---

# Setting Up Tdarr

What is Tdarr? Tdarr simply is a program that contains an entire interface that makes it easy for you to shrink or convert videos to a particular format without you having to understanding a single line of code. The only problem with Tdarr is that the GUI interface can be confusing for new users. As an expert user for many things, Tdarr took me several months to fully understand. I added this section recently to help you. Again, please ★ (Star) the project above that shows me other users care about the information provided.

## Deploying Tdarr Server

When deploying the Tdarr Server, you will sometimes see an option to deploy a Tdarr Node. The Tdarr Server template allows you to deploy an internal node. For purposes of this guide, I highly recommend to deploy your nodes seperately, even if only using one. If the Tdarr Server has issues, it is much easier to troubleshoot the just the Server instead of a Server/Node combo. 

First deploy Tdarr Server via Unraid via the Unraid App Store. Make sure it just says Tdarr, not Tdarr Node.

<img width="381" alt="image" src="https://github.com/user-attachments/assets/e3f60be8-5c2b-4ea1-8c36-af7e25097603" />
 
Next, the template will have some information. Call it _Server_ for simple sanity tracking purpose.

<img width="557" alt="image" src="https://github.com/user-attachments/assets/126ff9c9-7b32-4fdf-82cc-864bedf85700" />

The biggest thing you have to ensure is that the Server IP is correct, which should be your UNRAID server IP. Leave everything else alone and ensure that the node is _False_. As a resuolt of that, ignore the rest of the port numbers.

<img width="688" alt="image" src="https://github.com/user-attachments/assets/b70a2724-b0f7-463e-8da3-c1e7ad3d052b" />

** Tdarr Transcoding Location

Where you transcode on and how is very important including the amount of nodes and multiple transcodes. For a majority of users with an SSD/NVME and transcoding a few files at a time, you will be fine transcoding on that device. For heavy transcoding, read the bottleneck warning below.

*** Warning: Bottlenecks & SSD/Wear & Tear

I personally have a small NVME dedicated for Tdarr Transcodes. If your only transcoding a few files here and there, you'll be fine. For me, I have 3 graphics cards that each transcode 4 streams at a time. Having this much data transcode at one time all the time will bottle neck your NVME/SSD with your appdata. Avoid transcoding to a standard HHD at all cost. Do not transcode in the RAM (I have tried this even with 64GB of RAM) and Tdarr will generate many errors and it will also bottleneck your unraid system. The upside to transcoding to a cheap NVME is that all the wear and tear targets that NVME. Why wear down your good SSD/NVME with TBs and TBs of Tdarr Transcodes? I actually mannaged to wear down an NVME's life span to 0 with a SMART WARNING telling me (still works fine) soley because of Tdarr.

<img width="754" alt="image" src="https://github.com/user-attachments/assets/daac629c-3fe9-45e4-89e9-c8e50686e2ea" />

## Deploying Tdarr Node(s)



---

# AV1 Tdarr Flow

Change Log:

* v1: Original
* v2: Remove B Frames
* v3: Improved Quality Greatly
* v4: Added remove image from files, this would cause about a 25% failure rate for your files to transcode. Adding this allows a 100% conversion rate for AV1.

**JSON Script**: This script can be found [Here](av1_flow_v4.json).

<img width="824" alt="image" src="https://github.com/user-attachments/assets/54e5b72c-5f88-4264-a01c-833a8d67287c">

### What is the AV1 Flow?

The AV1 Flow is a preset in Tdarr that converts your media to AV1. It’s straightforward: input → process → encode → output. This is where you get those huge file-size savings.

### Importing the AV1 Flow in Tdarr

Import the provided AV1 Flow JSON into Tdarr. Then apply it to your libraries so Tdarr will start using your Intel ARC GPU for AV1 encoding (if configured).

![Adding a New Flow in Tdarr](https://i.imgur.com/nLzQi1b.png)

Scroll to the very bottom:

![Scroll to Find the Import Option](https://i.imgur.com/hmYNetQ.png)

Paste the JSON:

![Copy the JSON Content](https://i.imgur.com/Qe13kYg.png)

Once applied, Tdarr will begin shrinking your files to AV1 format.

---

## Optimizing AV1 Encoding Settings

Experiment with quality (CRF) and bitrate settings until you find a good balance between file size and video quality. Also, ensure hardware acceleration is on so the GPU does most of the heavy lifting.

---

# SABNZBD Speed Control

Enhance your SABnzbd experience with the SAB Speed Script. This tool dynamically adjusts your download speeds whenever someone is watching content from your Plex server, preventing bandwidth competition that could cause buffering and playback issues. By automatically slowing down your downloads during peak usage and offering a configurable “nighttime” mode for maximum speeds when your network is idle, the SAB Speed Script ensures a smoother, more efficient media streaming experience. The script can be found [Here](sab_speed_control.sh) and requires Tautulli for Plex Monitoring.

<img width="483" alt="image" src="https://github.com/user-attachments/assets/b04d53b1-9d5d-42ab-ab33-2ac2dd2449b0">

For this script to run, you need to install - USER SCRIPTS - from the UNRAID APP STORE. Once you save the script, ensure it is setup to STARTUP AT ARRAY. Also, click RUN IN THE BACKGROUND just to get it going. NOT REQUIRED FOR TDARR AV1!

<img width="403" alt="image" src="https://github.com/user-attachments/assets/728a6959-cfaf-44e5-8302-ab43372c87a1">

---

# Tdarr Node Killer Script

**Change Log**

* v1: Original Script
* v2: Script monitors PLEX via Tautulli to simplify processes

### Overview

This optional script frees up the GPU for Plex whenever Plex needs it. If Tdarr and Plex share the GPU, Tdarr might interfere with streaming performance. With this script:

- When Plex starts transcoding: the script stops the Tdarr node, giving the GPU to Plex.
- When Plex stops: after a short cooldown (e.g., 180 seconds), the script restarts Tdarr.

**SCRIPT**: The Tdarr Node Killer script can be found [Here](tdarr_node_killer.sh).

For this script to run, you need to install - USER SCRIPTS - from the UNRAID APP STORE. Once you save the script, ensure it is setup to STARTUP AT ARRAY. Also, click RUN IN THE BACKGROUND just to get it going.

<img width="403" alt="image" src="https://github.com/user-attachments/assets/728a6959-cfaf-44e5-8302-ab43372c87a1">

### Script Behavior

The script uses Tautulli’s API to detect when Plex is transcoding:

- If Plex is transcoding: kill the Tdarr node.
- After Plex stops, wait the cooldown period, then bring Tdarr back online.

This prevents rapid start/stop cycles if Plex users jump in and out often.

### Step-by-Step Implementation for Unraid

1. Tdarr node running, no Plex transcoding:

    ![Tdarr Node Running, No Plex Transcoding](https://i.imgur.com/PHRITk0.png)

2. Script monitoring for Plex transcoding:

    <img width="615" alt="image" src="https://github.com/user-attachments/assets/a0ebab4e-e178-4de3-87f7-00e749cfa6cd">

3. Plex user starts transcoding:

    ![Plex User Starts Transcoding](https://i.imgur.com/AT6hCUV.png)

4. Script detects Plex transcoding and stops Tdarr node:

    <img width="655" alt="image" src="https://github.com/user-attachments/assets/8b9b0cdc-9084-48ed-a1c0-b00e32f51dc6">

    ![Tdarr Node Stopped](https://i.imgur.com/KzdXHKf.png)

5. Tdarr node is completely stopped:

    ![Tdarr Node Dead](https://i.imgur.com/4gIzOkW.png)

### Script Behavior After Plex Transcoding Stops

The script doesn’t instantly bring Tdarr back up. It waits, say 3 minutes, to ensure Plex isn’t going to start transcoding again immediately.

1. Countdown before restarting Tdarr node:

    ![Countdown Before Restarting Tdarr Node](https://i.imgur.com/59AGRlv.png)

2. After the wait, Tdarr node is restarted:

    <img width="611" alt="image" src="https://github.com/user-attachments/assets/7ca1d8b0-efac-44ab-9701-24ef525f33c7">

    ![Tdarr Node Coming Back Online](https://i.imgur.com/TTPVyt0.png)

3. Tdarr node fully online again:

    ![Tdarr Node Fully Online](https://i.imgur.com/M1M2vSL.png)

### Troubleshooting Common Issues

- Plex not using GPU? Check your Docker template and Plex settings.
- Tdarr not restarting? Ensure the script and Tautulli API are working correctly.
- High CPU usage? Check if HDR tone mapping is enabled and supported. Also verify GPU drivers and plugins are up-to-date.

---

## Experimental: Running the Script on Other Operating Systems

You can run this script on other Linux distros that support Docker and systemd. The process is basically the same: place the script, create a systemd service, and start it up.

### Step-by-Step Implementation for Other OSes

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
