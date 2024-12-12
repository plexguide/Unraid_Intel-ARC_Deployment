# Guide to Intel ARC AV1 Encoding on Unraid + Tdarr Node Killer + SAB Speed Control (Bonus)

**Want to help?** Click the ★ (Star) button in the upper-right corner!

This guide shows you how to optimize your media library with AV1 encoding on Unraid while efficiently managing GPU resources shared between Plex and Tdarr. By following these steps, you will reduce video file sizes, save substantial storage space, and ensure Plex always has access to the GPU when it needs it. You will also learn how to pause Tdarr automatically when Plex requires the GPU, then restart Tdarr afterward. Additionally, this guide explains how to adjust SABnzbd download speeds based on Plex streaming activity to prevent buffering.

**What you’ll learn:**
- How to configure your Intel ARC GPU on Unraid.
- How to set up and optimize Tdarr for AV1 encoding.
- How to manage SABnzbd download speeds based on Plex streaming activity.
- How to use the Tdarr Node Killer script to prioritize Plex GPU usage over Tdarr.

Whether you’re an experienced Unraid user or just beginning, this step-by-step guide will help you achieve better resource management, significant storage savings, and an improved streaming experience.

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

AV1 encoding drastically reduces file sizes. Using three Intel ARC GPUs to encode just 10-15% of a large library saved about 116TB. For a 300TB collection, careful AV1 conversion could reduce it to 75-100TB.

<img width="373" alt="image" src="https://github.com/user-attachments/assets/09d36726-56d9-4c53-8589-eca2173e7283">

In other words, AV1 can deliver huge storage and cost savings.

---

## AV1 Drawbacks

AV1 is not perfect. Some devices may not support AV1 decoding natively, and AV1 encoding can be more resource-intensive, taking longer to complete. For more details, visit the [AV1 Drawbacks](https://github.com/plexguide/Unraid_Intel-ARC_Deployment/wiki/AV1-Drawbacks) page.

---

## Upgrading to Unraid 7.0 and Installing Required Plugins

Ensure you run Unraid 7.0 or newer, and install the required GPU plugins before setting up s or using the Tdarr Node Killer script.

### Installing Intel GPU TOP Plugin

Install **Intel GPU TOP** by ich777 from the Unraid Community Apps. It lets you monitor Intel ARC GPU performance directly in Unraid.
 
![Intel GPU TOP Plugin](https://i.imgur.com/0bHRqya.png)

### Installing GPU Statistics Plugin

Install the **GPU Statistics** plugin by b3rs3rk. With Intel GPU TOP, this provides comprehensive GPU usage details during encoding or transcoding.

![GPU Statistics Plugin](https://i.imgur.com/lJZgPvC.png)

After installing both, you can see real-time GPU usage:

![GPU Usage Example 1](https://i.imgur.com/toOvgvN.png)  
![GPU Usage Example 2](https://i.imgur.com/jDbrB5a.png)

---

# Deploying Plex with Intel ARC GPU Support

### Adding the Intel ARC GPU to the Plex Docker Template

In your Plex Docker template, add the Intel ARC GPU as a device. Without this, Plex will not recognize the GPU for hardware acceleration.

![Add Intel ARC GPU to Plex Template](https://i.imgur.com/Da4oeGV.png)

### Configuring Plex Settings

Enable hardware transcoding in Plex and HDR tone mapping (if supported). If multiple GPUs exist, choose the correct one.

<img width="1020" alt="image" src="https://github.com/user-attachments/assets/2ed05f55-ee92-4011-9f6f-99c24b5d1a3f">

### Verifying GPU Transcoding

Play a media file that requires transcoding. Check Plex’s dashboard and GPU stats. You should see minimal CPU usage and smooth playback. If you have an AV1 file, play that for the test to verify that AV1 transcoding is working also!

![Plex GPU Transcoding](https://i.imgur.com/Zz9jfYo.png)

---

# Setting Up Tdarr

**What is Tdarr?**  
Tdarr simplifies media transcoding with a user-friendly interface. It automates conversions without you needing complex command-line knowledge. Although it may seem confusing initially, once you understand it, Tdarr becomes an indispensable tool for media optimization.

If you find this guide helpful, consider clicking the ★ (Star) button above. It shows your support and helps others find this resource.

## Deploying Tdarr Server

When installing Tdarr, you may see an option to deploy both the server and node in one container. For easier troubleshooting, deploy them separately.

1. Install **Tdarr** (not Tdarr Node) from the Unraid App Store.
2. Name it clearly, e.g., “Server” “TServer” “TdarrServer”
3. Ensure the server IP is correct (usually your Unraid server’s IP).
4. Set the internal node option to **False**, so you will deploy a separate node container later.

<img width="381" alt="image" src="https://github.com/user-attachments/assets/e3f60be8-5c2b-4ea1-8c36-af7e25097603" />

<img width="557" alt="image" src="https://github.com/user-attachments/assets/126ff9c9-7b32-4fdf-82cc-864bedf85700" />

<img width="688" alt="image" src="https://github.com/user-attachments/assets/b70a2724-b0f7-463e-8da3-c1e7ad3d052b" />

## Tdarr Transcoding Location

Choose a suitable location for transcoding. For occasional use, an SSD/NVMe cache is fine. For heavy use (multiple streams, multiple GPUs), consider a dedicated NVMe. Avoid HDDs or RAM to prevent bottlenecks and errors. 

### Warning: Bottlenecks & SSD Wear

Continuous transcoding strains SSD/NVMe drives. Using a dedicated, cost-effective NVMe helps preserve your primary drives’ health. 

Note this is optional. I have a cheap 512GB NVME that Tdarr transcodes to. Since Tdarr will transcode 100s of Terabytes of, avoid wearing out your primary SSD/NVME. I had an NVME provide me BAD SMART warning for reliability (due to wear and tear). I still use it, but cautiously (and works fine).

I also personally encountered where Tdarr bottleneck my primary NVME due to the amount of GPU's and Transcodes reading and writing to my primary appdata NVME.

<img width="754" alt="image" src="https://github.com/user-attachments/assets/daac629c-3fe9-45e4-89e9-c8e50686e2ea" />

## Deploying Tdarr Node(s)

After deploying the Tdarr Server, install the **Tdarr Node** (listed separately). The node performs transcoding, while the server manages nodes, libraries, and workflows.

<img width="397" alt="image" src="https://github.com/user-attachments/assets/6b384a42-194d-4089-b1ff-89d6cca77728" />

1. Install **Tdarr Node** from the Unraid App Store.
2. Give it a clear name, e.g., Node1. For multiple GPUs, deploy more nodes (N1, N2, etc.).

<br><img width="477" alt="image" src="https://github.com/user-attachments/assets/8ce39a4d-1479-433c-b3c8-9eceb4ebf044" /><br>
3. Ensure the server IP and Node IP match.

<br><img width="749" alt="image" src="https://github.com/user-attachments/assets/736eff11-ec78-441d-9c82-0f11def877bd" /><br>
4. Keep configs/logs organized per node.
5. Match the transcode cache path from the server’s template. Add node identifiers if using multiple nodes.
6. Assign the correct GPU to each node. If multiple nodes exist, ensure they do not share the same GPU.

<br><img width="769" alt="image" src="https://github.com/user-attachments/assets/b7a2d3e3-288b-4f16-9424-74a82b8f6451" /><br>

To identify GPUs:
* `ls -la /dev/dri/`

<br><img width="457" alt="image" src="https://github.com/user-attachments/assets/3e8b0028-c1b2-4517-b42d-731c2b01d7f3" /><br>

**WARNING:** One entry might be your iGPU. Do not assign the iGPU to a Tdarr Node. 

_Tip:_ Visit your Plex and headover to Transcoding (as shown in the picture) and click your GPU list. The listed order shown in Plex is the same order of the GPUs when typing `ls -la /dev/dri`. In the photo example below, you will notice I skipped render129, which is actually the iGPU. 

<br><img width="701" alt="image" src="https://github.com/user-attachments/assets/1dfa28a8-ddd4-4c0b-a1f9-f4ff2b9c5e9b" /><br>

Plex lists my order of graphics cards as `Intel ARC 380 > Raphel (AMD iGPU) > Intel ARC 380 > Intel ARC 380`. The second one listed on Plex (Raphel - AMD iGPU) is in the same order of `ls -la /dev/dri` as render129. Basically, I skipped that one and used render130 for (Node2) and render131 for N3 (Node3).

### Configuring Tdarr

Go to:
* http://ip-address:8265

If configured correctly, you will see your nodes:

<br><img width="409" alt="image" src="https://github.com/user-attachments/assets/db6b2dc8-6fb7-4acf-be86-785705a44961" /><br>

If you have multiple nodes, repeat the following steps for each:

1. Click a Node.
2. Set the numbers according to your ARC card type:

- ARC 310  
  - Transcode: CPU (0), GPU (3)  
  - Healthcheck: CPU (2), GPU (0)

- ARC 380  
  - Transcode: CPU (0), GPU (4)  
  - Healthcheck: CPU (2), GPU (0)

- ARC 500/700 Series  
  - Transcode: CPU (0), GPU (6)  
  - Healthcheck: CPU (2), GPU (0)

<br><img width="548" alt="image" src="https://github.com/user-attachments/assets/8dc965c7-d801-42b3-af1f-c5310e2e2fad" /><br>

3. Click **Options**, scroll towards the bottom, enable “GPU Workers to do CPU Tasks,” then close the window.

<br><img width="431" alt="image" src="https://github.com/user-attachments/assets/3cb3786a-025a-48c6-ba72-c6835effef11" /><br>

4. In the staging section, check “auto-accept successful transcodes.” Not doing this prevents Tdarr from replacing old files and wastes space.

<br><img width="745" alt="image" src="https://github.com/user-attachments/assets/b78a71c2-71c9-4a01-a5c7-40d34ff26775" /><br>

5. Scroll further down to “Status” and adjust the order of transcoding. For example, start with your largest files. Customize as desired.

<br><img width="774" alt="image" src="https://github.com/user-attachments/assets/111cbddd-bfe3-437f-b79e-7fd00ec90c59" /><br>

---

# Setting up the AV1 Tdarr Flow

**Change Log:**
- **v1:** Original AV1 flow
- **v2:** Removed B-frames
- **v3:** Improved quality
- **v4:** Removed images from files, reducing failure rates from ~25% to nearly 0%

**JSON Script:** [av1_flow_v4.json](av1_flow_v4.json)

<img width="824" alt="image" src="https://github.com/user-attachments/assets/54e5b72c-5f88-4264-a01c-833a8d67287c">

### What is the AV1 Flow?

The AV1 Flow is a predefined workflow that transcodes media into AV1, delivering significant space savings without requiring you to master encoding parameters. This step is required prior to setting up the libraries!

### Importing the AV1 Flow in Tdarr

1. Open the Flows section in Tdarr.
2. Scroll down and select “Import.”
3. Paste the AV1 Flow JSON.
4. Apply it to your libraries.

![Adding a New Flow in Tdarr](https://i.imgur.com/nLzQi1b.png)  
![Scroll to Import Option](https://i.imgur.com/hmYNetQ.png)  
![Pasting the JSON Content](https://i.imgur.com/Qe13kYg.png)

## Optimizing AV1 Encoding Settings

Adjust CRF and bitrate in the AV1 flow to balance quality and file size. Ensure hardware acceleration is on so the GPU does most of the work. Test out on a few files to figure where you like it, but I have discovered over time the set numbers provide the best balance between quality and size.

Keep in mind the following:

* Bigger Number: Worst Quality, Smaller File
* Lower Number: Better Quality, Bigger File

<br><img width="467" alt="image" src="https://github.com/user-attachments/assets/59439420-8a46-4548-b63f-47076f1a5a6b" /><br>
<br><img width="448" alt="image" src="https://github.com/user-attachments/assets/b001501f-8757-4ca3-9b63-c74d24fe4da8" /><br>

---

# Setting Up Tdarr Libraries

Libraries let you target specific media locations. For simplicity, we’ll use “tv” and “movies” as examples, but you can create as many as needed.

1. Click **Libraries**:

<br><img width="646" alt="image" src="https://github.com/user-attachments/assets/2bd6102a-9694-42f1-842d-3cc70f087a0f" /><br>

2. Click **Library+**:

<br><img width="130" alt="image" src="https://github.com/user-attachments/assets/f5c6a119-afb6-4f63-8dbc-c2f1db63c019" /><br>

3. Name it “TV” or “Movies.” Repeat these steps for additional libraries.
4. Under **Source**, set your media path. Also below that, turn on the [hourly] scan to find new items (important).

<br><img width="909" alt="image" src="https://github.com/user-attachments/assets/2142aa48-a7a8-4e3f-9dcb-d7df3aed5570" /><br>
<br><img width="292" alt="image" src="https://github.com/user-attachments/assets/e5bb4b33-5115-4d65-a4de-7a28d705a0d0" /><br>

5. Under **Transcode Cache**, set the path as shown (e.g., /temp).

<br><img width="404" alt="image" src="https://github.com/user-attachments/assets/22f9c1f8-a3d8-49a9-8ce6-678c1de28ce4" /><br>

6. Under **Filters**, add `AV1` to “Codecs to Skip” so you do not re-encode existing AV1 files. You can also skip small files if desired.

<br><img width="297" alt="image" src="https://github.com/user-attachments/assets/8ed82ff6-aa65-4fbe-a576-39810eeed1c3" /><br>

7. Under **Transcode Options**, deselect classic plugins, select the “Flows” tab, and choose the AV1 flow. If you have not yet imported the AV1 flow, follow the steps in the AV1 Flow section above this section and then return here.

<br><img width="1004" alt="image" src="https://github.com/user-attachments/assets/a0a4028d-c539-4df9-8e09-4b25a6a2a2a5" /><br>

8. Repeat for all your libraries.
9. Perform a **FRESH NEW SCAN** to apply changes.

<br><img width="284" alt="image" src="https://github.com/user-attachments/assets/0556d967-8ab3-4628-86d4-12a53a369c0f" /><br>

10. Return to the home page. After a few minutes, you should see transcoding activity. If not, review GPU and node assignments.

<br><img width="1158" alt="image" src="https://github.com/user-attachments/assets/642f3102-7cfa-4c49-b1d0-0f408930f36d" /><br>

11. If errors increase rapidly, double-check configurations or GPU assignments.

<br><img width="1254" alt="image" src="https://github.com/user-attachments/assets/474ce9bf-d883-4b31-afa7-f0ccb909dd0f" /><br>

---

# SABNZBD Speed Control - Bonus

Use the SAB Speed Script to dynamically adjust SABnzbd download speeds based on Plex streaming activity. It slows downloads when Plex is active, preventing buffering, and speeds them up off-peak.

**Requirements:**
- [Tautulli](https://tautulli.com/) for Plex monitoring
- [User Scripts](https://forums.unraid.net/topic/87144-plugin-user-scripts/) from the Unraid App Store

**Script:** [sab_speed_control.sh](sab_speed_control.sh)

Run it at array startup and in the background.

<img width="483" alt="image" src="https://github.com/user-attachments/assets/b04d53b1-9d5d-42ab-ab33-2ac2dd2449b0">
<img width="403" alt="image" src="https://github.com/user-attachments/assets/728a6959-cfaf-44e5-8302-ab43372c87a1">

---

# Tdarr Node Killer Script

**Change Log:**  
- **v1:** Original script  
- **v2:** Uses Tautulli for simpler detection

### Overview

The Tdarr Node Killer script ensures Plex gets GPU priority. If Plex and Tdarr share the GPU, the script pauses Tdarr when Plex begins transcoding and restarts it after Plex finishes.

### Script Behavior

- When Plex starts transcoding, it stops the Tdarr Node.
- After Plex stops, it waits a cooldown (e.g., 3 minutes) before restarting Tdarr, preventing rapid cycling.

**Script:** [tdarr_node_killer.sh](tdarr_node_killer.sh)

Install User Scripts, add the script, set it to run at array startup, and run it in the background.

<img width="403" alt="image" src="https://github.com/user-attachments/assets/728a6959-cfaf-44e5-8302-ab43372c87a1">

### Step-by-Step Implementation for Unraid

1. Tdarr Node [N1] running, no Plex transcoding:
   <br><img width="543" alt="image" src="https://github.com/user-attachments/assets/c4d99d6c-e8f9-4d38-a103-f8071f07a4fa" /><br>

2. Script monitoring Plex:
   <br><img width="615" alt="image" src="https://github.com/user-attachments/assets/a0ebab4e-e178-4de3-87f7-00e749cfa6cd"><br>

3. Plex user starts transcoding:
   
   ![Plex User Starts Transcoding](https://i.imgur.com/AT6hCUV.png)

4. Script detects transcoding & stops Tdarr Node:
   <br><img width="655" alt="image" src="https://github.com/user-attachments/assets/8b9b0cdc-9084-48ed-a1c0-b00e32f51dc6"><br>
   
   <br><img width="322" alt="image" src="https://github.com/user-attachments/assets/68dcc0c5-b347-4bed-86cb-53e58637b48b" /><br>

5. Tdarr Node [N1] completely stopped:
   <br><img width="548" alt="image" src="https://github.com/user-attachments/assets/e10fc050-2000-49a6-be46-a49b9a8609e2" /><br>

### Script Behavior After Plex Transcoding Stops

After Plex finishes, the script waits, then restarts Tdarr:

1. Countdown 180 seconds before restarting the shutdown docker container.

2. Tdarr Node restarts after cooldown:
   
   <br><img width="611" alt="image" src="https://github.com/user-attachments/assets/7ca1d8b0-efac-44ab-9701-24ef525f33c7"><br>
   
   <br><img width="323" alt="image" src="https://github.com/user-attachments/assets/9730388b-c5e8-42fc-9392-69b58d9554d7" /><br>

3. Tdarr Node fully online again:
   
   ![Tdarr Node Online](https://i.imgur.com/M1M2vSL.png)

### Troubleshooting Common Issues

- **Plex Not Using GPU?** Check Plex Docker template and transcoding settings.
- **Tdarr Not Restarting?** Verify script, Tautulli API settings, and background execution.
- **High CPU Usage?** If HDR tone mapping is on, ensure GPU and drivers support it. Update all plugins and drivers.

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
