# Guide to Intel ARC AV1 Encoding on Unraid + Tdarr Node Killer + SAB Speed Control (Bonus)

**Want to help?** Click the ★ (Star) button in the upper-right corner!

This guide shows you how to optimize your media library with AV1 encoding on Unraid while also managing GPU resources between Plex and Tdarr. You’ll learn how to significantly reduce video file sizes, save substantial storage space, and automatically free up your GPU for Plex transcodes when needed. Additionally, you’ll learn how to pause Tdarr when Plex requires the GPU and then restart Tdarr once Plex is done.

**What you’ll learn:**
- How to configure your Intel ARC GPU on Unraid.
- How to set up and optimize Tdarr for AV1 encoding.
- How to manage SABnzbd download speeds based on Plex streaming activity.
- How to use the Tdarr Node Killer script to give Plex GPU priority over Tdarr.

Whether you’re a seasoned Unraid user or just starting out, this step-by-step guide will help you achieve better resource management, substantial storage savings, and an improved streaming experience.

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
- [AV1 Tdarr Flow](#av1-tdarr-flow)
  - [What is the AV1 Flow?](#what-is-the-av1-flow)
  - [Importing the AV1 Flow in Tdarr](#importing-the-av1-flow-in-tdarr)
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

AV1 encoding can dramatically reduce your file sizes. In practice, using three Intel ARC GPUs to encode just 10-15% of a large library resulted in roughly 37TB of saved space. For a 300TB collection, this could bring the total size down to around 75-100TB with careful AV1 conversion.

<img width="373" alt="image" src="https://github.com/user-attachments/assets/09d36726-56d9-4c53-8589-eca2173e7283">

In other words, AV1 can provide huge storage and cost savings.

---

## AV1 Drawbacks

AV1 isn’t flawless. Some devices may not natively support AV1 decoding yet. Additionally, AV1 encoding can be more resource-intensive and may take longer. For more details, check out the [AV1 Drawbacks](https://github.com/plexguide/Unraid_Intel-ARC_Deployment/wiki/AV1-Drawbacks) page to understand compatibility issues and potential trade-offs.

---

## Upgrading to Unraid 7.0 and Installing Required Plugins

Before setting up AV1 flows or using the Tdarr Node Killer Script, ensure you’re running Unraid 7.0 (or newer) and have the necessary GPU-related plugins.

### Installing Intel GPU TOP Plugin

Install **Intel GPU TOP** by ich777 from the Unraid Community Apps store. This plugin allows you to monitor your Intel ARC GPU’s performance directly from the Unraid dashboard.
 
![Intel GPU TOP Plugin](https://i.imgur.com/0bHRqya.png)

### Installing GPU Statistics Plugin

Next, install the **GPU Statistics** plugin by b3rs3rk. With Intel GPU TOP, you’ll gain comprehensive insights into your GPU’s usage during encoding or transcoding tasks.

 
![GPU Statistics Plugin](https://i.imgur.com/lJZgPvC.png)

Once installed, you’ll see real-time GPU usage:

*(No width specified for these screenshots)*  
![GPU Usage Example 1](https://i.imgur.com/toOvgvN.png)  
![GPU Usage Example 2](https://i.imgur.com/jDbrB5a.png)

---

# Deploying Plex with Intel ARC GPU Support

### Adding the Intel ARC GPU to the Plex Docker Template

In your Plex Docker template, add the Intel ARC GPU as a device. Without this, Plex won’t recognize the GPU for hardware acceleration.

*(No width specified originally)*  
![Add Intel ARC GPU to Plex Template](https://i.imgur.com/Da4oeGV.png)

### Configuring Plex Settings

Enable hardware transcoding in Plex and HDR tone mapping (if supported). If multiple GPUs are present, select the correct one in Plex settings.

<img width="1020" alt="image" src="https://github.com/user-attachments/assets/2ed05f55-ee92-4011-9f6f-99c24b5d1a3f">

### Verifying GPU Transcoding

Play a media file that requires transcoding. Check Plex’s dashboard and your GPU stats to confirm the GPU is handling the task. You should see minimal CPU usage and smooth playback.

  
![Plex GPU Transcoding](https://i.imgur.com/Zz9jfYo.png)

---

# Setting Up Tdarr Server & Nodes

**What is Tdarr?**  
Tdarr simplifies media transcoding through a user-friendly interface. It automates batch conversions without requiring manual command-line settings. Although the interface can be confusing at first, once you understand it, Tdarr becomes a powerful tool for media optimization.

If you find this guide helpful, please consider clicking the ★ (Star) button above. It helps others discover this content and shows your support.

## Deploying Tdarr Server

When installing Tdarr, you may see an option to deploy both a Tdarr Server and a Tdarr Node in one container. To simplify troubleshooting, it’s recommended to deploy them separately.

1. Install the **Tdarr Server** via the Unraid App Store (ensure it’s labeled “Tdarr,” not “Tdarr Node”).
2. Name it something identifiable, like “Tdarr_Server.” (I use - Server)
3. Ensure the server IP is set correctly, usually your Unraid server’s IP.
4. Set the internal node option to **False**, so you’ll deploy a separate node later.

<img width="381" alt="image" src="https://github.com/user-attachments/assets/e3f60be8-5c2b-4ea1-8c36-af7e25097603" />

<img width="557" alt="image" src="https://github.com/user-attachments/assets/126ff9c9-7b32-4fdf-82cc-864bedf85700" />

<img width="688" alt="image" src="https://github.com/user-attachments/assets/b70a2724-b0f7-463e-8da3-c1e7ad3d052b" />

## Tdarr Transcoding Location

Your transcoding location and hardware choice are crucial. For occasional transcoding, using an SSD/NVMe cache drive is fine. For heavy and continuous transcoding (multiple streams, multiple GPUs), consider dedicating a separate NVMe drive to handle the workload. Avoid using HDDs or RAM for transcoding as they cause performance issues and potential errors.

### Warning: Bottlenecks & SSD Wear

Heavier workloads can wear out your SSD/NVMe quickly. By using a dedicated, inexpensive NVMe for transcoding, you protect your main drives from excessive wear.

<img width="754" alt="image" src="https://github.com/user-attachments/assets/daac629c-3fe9-45e4-89e9-c8e50686e2ea" />

## Deploying Tdarr Node(s)

After setting up the Tdarr Server, install the **Tdarr Node** container (listed separately in the Unraid App Store). The node handles the actual transcoding, while the server manages nodes, libraries, and workflows.

<img width="397" alt="image" src="https://github.com/user-attachments/assets/6b384a42-194d-4089-b1ff-89d6cca77728" />

1. Install the **Tdarr Node** via the Unraid App Store (ensure it’s labeled “Tdarr Node,” not “Tdarr).
2. Name it something identifiable, like - Node1 or N1
   - Using 2 or more GPU's? Repeat the process and call the next node - Node2 or N2
3. Ensure the server IP is set correctly, usually your Unraid server’s IP. Also ensure the NodeIP is the same IP (trust me on it)
4. Make sure the configs and logs match the node # for simplicity.
   - Using 2 or more GPU's? Repeat the process and label each one based off the node name - node2 or n2
5. Ensure the transcode cache matches the server's template path that you created. For this, add the node name at the end such n1 or node1
6. Ensure to assign the correct GPU to the node. If your deploying 2 or more nodes, ensure it's using the same device. To see your GPUs, type:

```ls -la /dev/dri/ ``` 

**WARNING**:

One of these numbers will reflect your iGPU, even for AMD processors. Do not assign the iGPU to your Tdarr Node! I have not found a good way to discover which one the iGPU from the CMD line... but if you goto Plex and Transcode and look at the order of the GPUs from the menu, it actually follows that order.
   
<img width="477" alt="image" src="https://github.com/user-attachments/assets/8ce39a4d-1479-433c-b3c8-9eceb4ebf044" />
<img width="749" alt="image" src="https://github.com/user-attachments/assets/736eff11-ec78-441d-9c82-0f11def877bd" />
<img width="769" alt="image" src="https://github.com/user-attachments/assets/b7a2d3e3-288b-4f16-9424-74a82b8f6451" />
<img width="457" alt="image" src="https://github.com/user-attachments/assets/3e8b0028-c1b2-4517-b42d-731c2b01d7f3" />

### Configuring Tdarr

Once your server and node(s) are deployed, visit
```http://ip-address:8265```

If you setup your nodes correctly, you should see the following below:
<br><img width="409" alt="image" src="https://github.com/user-attachments/assets/db6b2dc8-6fb7-4acf-be86-785705a44961" /><br>

Note, repeat the following below if you have more than 1 node.

1. Click a Node
2. Set the numbers for the following ARC card type (picture below example below)

- ARC 310
  - Transcode: CPU (O) GPU (3)
  - Healthcheck: CPU (2) GPU (0)
 
- ARC 380
  - Transcode: CPU (O) GPU (4)
  - Healthcheck: CPU (2) GPU (0) 

- ARC 500/700 Series
  - Transcode: CPU (O) GPU (6)
  - Healthcheck: CPU (2) GPU (0) 

<br><img width="548" alt="image" src="https://github.com/user-attachments/assets/8dc965c7-d801-42b3-af1f-c5310e2e2fad" /><br>

3. Now click Options and scroll towards the mid bottom and ensure the GPU Works to do CPU Tasks are turned [On] and click the X in the upper right when done.

<br><img width="431" alt="image" src="https://github.com/user-attachments/assets/3cb3786a-025a-48c6-ba72-c6835effef11" /><br>

4. Scroll down more to staging section and make sure to [CHECK] auto-accept successful transcodes. Failing to do so prevents the transcoded files from replacing the old files and will fill up your hard drive because the files are transcoded, but have no where to go.

<br><img width="745" alt="image" src="https://github.com/user-attachments/assets/b78a71c2-71c9-4a01-a5c7-40d34ff26775" /><br>

5. Continue to scroll to status downward and match the picture. I recommend for you to transcode your largest files first, but you can choose whatever you like!

<br><img width="774" alt="image" src="https://github.com/user-attachments/assets/111cbddd-bfe3-437f-b79e-7fd00ec90c59" /><br>

---

# Setting up Tdarr Libraries

The purpose of setting up libraries is to target
 


[UNDER CONSTRUCTION - DEPLOYING TDARR]

---

# AV1 Tdarr Flow

**Change Log:**
- **v1:** Original AV1 flow.
- **v2:** Removed B-frames.
- **v3:** Greatly improved quality.
- **v4:** Removed images from files, reducing failure rates from ~25% to nearly 0%.

**JSON Script:** [av1_flow_v4.json](av1_flow_v4.json)

<img width="824" alt="image" src="https://github.com/user-attachments/assets/54e5b72c-5f88-4264-a01c-833a8d67287c">

### What is the AV1 Flow?

The AV1 Flow is a predefined workflow that converts your media into the AV1 format. Once applied, Tdarr processes your libraries, delivering significant space savings without you needing to master complex transcoding parameters.

### Importing the AV1 Flow in Tdarr

1. Open Tdarr’s flows section.
2. Scroll down and select the “Import” option.
3. Paste the AV1 Flow JSON script.
4. Apply it to your libraries.

  
![Adding a New Flow in Tdarr](https://i.imgur.com/nLzQi1b.png)  
![Scroll to Import Option](https://i.imgur.com/hmYNetQ.png)  
![Pasting the JSON Content](https://i.imgur.com/Qe13kYg.png)

Once set, Tdarr will begin transcoding your files to AV1.

---

## Optimizing AV1 Encoding Settings

Experiment with quality (CRF) and bitrate settings in the AV1 Flow to find a balance between file size and image quality. Ensure hardware acceleration is enabled so the GPU handles most of the processing.

---

# SABNZBD Speed Control - Bonus

The SAB Speed Script dynamically adjusts SABnzbd download speeds based on Plex streaming activity. When Plex is active, it reduces download speeds to prevent buffering. During off-peak times, it ramps speeds back up, maximizing your bandwidth efficiency.

**Requirements:**
- [Tautulli](https://tautulli.com/) for Plex monitoring.
- [User Scripts](https://forums.unraid.net/topic/87144-plugin-user-scripts/) plugin from the Unraid App Store.

**Script:** [sab_speed_control.sh](sab_speed_control.sh)

After saving the script, configure it to run at array startup and choose “Run in Background.”

<img width="483" alt="image" src="https://github.com/user-attachments/assets/b04d53b1-9d5d-42ab-ab33-2ac2dd2449b0">

<img width="403" alt="image" src="https://github.com/user-attachments/assets/728a6959-cfaf-44e5-8302-ab43372c87a1">

---

# Tdarr Node Killer Script

**Change Log:**  
- **v1:** Original Script  
- **v2:** Uses Tautulli to monitor Plex, simplifying detection.

### Overview

The Tdarr Node Killer script ensures Plex always has priority access to the GPU. If Plex and Tdarr share the same GPU, Tdarr’s transcoding tasks can pause whenever Plex starts transcoding, preserving a smooth streaming experience.

### Script Behavior

- When Plex starts transcoding (detected via Tautulli’s API), the script stops the Tdarr Node.
- After Plex stops transcoding, the script waits a cooldown (e.g., 3 minutes) before restarting Tdarr. This prevents rapid start/stop cycles if users frequently pause or stop streaming.

**Script:** [tdarr_node_killer.sh](tdarr_node_killer.sh)

Install the User Scripts plugin, add the script, set it to run at array startup, and run it in the background.

<img width="403" alt="image" src="https://github.com/user-attachments/assets/728a6959-cfaf-44e5-8302-ab43372c87a1">

### Step-by-Step Implementation for Unraid

1. Tdarr Node Running, No Plex Transcoding:
   
     
   ![Tdarr Node Running](https://i.imgur.com/PHRITk0.png)

2. Script Monitoring Plex:
   
   <img width="615" alt="image" src="https://github.com/user-attachments/assets/a0ebab4e-e178-4de3-87f7-00e749cfa6cd">

3. Plex User Starts Transcoding:
   
     
   ![Plex User Starts Transcoding](https://i.imgur.com/AT6hCUV.png)

4. Script Detects Transcoding & Stops Tdarr Node:
   
   <img width="655" alt="image" src="https://github.com/user-attachments/assets/8b9b0cdc-9084-48ed-a1c0-b00e32f51dc6">
   
     
   ![Tdarr Node Stopped](https://i.imgur.com/KzdXHKf.png)

5. Tdarr Node Completely Stopped:
   
     
   ![Tdarr Node Dead](https://i.imgur.com/4gIzOkW.png)

### Script Behavior After Plex Transcoding Stops

The script waits a set cooldown period after Plex finishes before restarting the Tdarr Node.

1. Countdown Before Restarting Tdarr Node:
   
     
   ![Countdown](https://i.imgur.com/59AGRlv.png)

2. Tdarr Node Restarts After Cooldown:
   
   <img width="611" alt="image" src="https://github.com/user-attachments/assets/7ca1d8b0-efac-44ab-9701-24ef525f33c7">
   
     
   ![Tdarr Node Coming Online](https://i.imgur.com/TTPVyt0.png)

3. Tdarr Node Fully Online Again:
   
     
   ![Tdarr Node Online](https://i.imgur.com/M1M2vSL.png)

### Troubleshooting Common Issues

- **Plex Not Using GPU?** Double-check Docker template settings and Plex’s hardware transcoding settings.
- **Tdarr Not Restarting?** Verify the script and Tautulli API settings. Make sure the script runs in the background.
- **High CPU Usage?** If HDR tone mapping is on, ensure your GPU and drivers support it. Update all plugins and drivers.

---

## Experimental: Running the Script on Other Operating Systems

You can run the Tdarr Node Killer script on other Linux distributions or operating systems that support Docker and systemd. The process is similar: place the script, grant proper permissions, and create a systemd service.

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
