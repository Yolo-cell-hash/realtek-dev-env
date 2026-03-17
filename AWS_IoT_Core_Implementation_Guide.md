# AWS IoT Core Implementation Guide — VDB System

## Don't Panic! Here's the Big Picture

Your MQTT schema is well-designed. Deploying it on AWS IoT Core is simpler than it looks because IoT Core **is** the MQTT broker — you don't install or manage anything. You just configure it.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        YOUR SYSTEM (Simplified)                     │
│                                                                     │
│  ┌──────────┐        ┌──────────────────┐        ┌──────────────┐  │
│  │ Realtek   │  MQTT  │  AWS IoT Core    │  MQTT  │  Mobile App  │  │
│  │ Ameba Pro │◄──────►│  (MQTT Broker)   │◄──────►│  (User)      │  │
│  │ (VDB)     │  TLS   │                  │  WSS   │              │  │
│  └──────────┘        │  ┌──────────────┐ │        └──────────────┘  │
│                      │  │ Rules Engine │ │                          │
│                      │  └──────┬───────┘ │                          │
│                      └─────────┼─────────┘                          │
│                                │                                    │
│                    ┌───────────┼───────────┐                        │
│                    ▼           ▼           ▼                        │
│              ┌──────────┐ ┌────────┐ ┌──────────┐                  │
│              │ DynamoDB  │ │ Lambda │ │   SNS    │                  │
│              │ (Logs)    │ │(Logic) │ │ (Push)   │                  │
│              └──────────┘ └────────┘ └──────────┘                  │
└─────────────────────────────────────────────────────────────────────┘
```

### What AWS IoT Core Gives You (Free in Sandbox)
- **MQTT broker** — fully managed, auto-scaling, no server to run
- **X.509 certificate auth** — secure device identity
- **IoT Policies** — your ACL rules, but in JSON
- **Rules Engine** — route MQTT messages to DynamoDB, Lambda, SNS, S3, etc.
- **Device Shadow** — store last known device state
- **MQTT Test Client** — test right in the AWS Console (browser!)
- **Free Tier**: 500K messages/month, 225K connection-minutes/month (plenty for sandbox)

---

## Key Questions Answered Before We Start

### Q1: MQTT 3.1.1 vs MQTT 5.0 — Which to Use?

**Decision: Use MQTT 3.1.1** ✅

```
MQTT 3.1.1 (Recommended for you)      MQTT 5.0 (Skip for now)
─────────────────────────────          ─────────────────────────
✅ Realtek Ameba Pro SDK supports it   ❌ Ameba Pro SDK may not support it
✅ Universal — every MQTT library      ⚠️  Newer, some libraries incomplete
   supports 3.1.1
✅ Simpler to debug and understand      Extra features you don't need yet:
✅ AWS IoT Core fully supports it         • Reason codes (detailed errors)
✅ All mobile app MQTT libs support it    • Message expiry timers
✅ Your schema already works with it      • Shared subscriptions
                                          • Topic aliases

Bottom line: 3.1.1 does everything you need for this project.
You can upgrade to 5.0 later as a firmware/SDK update if needed.
Your topics and payloads don't change — just the protocol version.
```

---

### Q2: What is the Rules Engine?

Think of it as **automated triggers** that run the moment a message arrives.

```
Without Rules Engine (you'd need a server running 24/7):
  Device → IoT Core → [Your Server listening] → Server saves to DB
                                ↑
                          You pay for this server!
                          It can crash, needs maintenance

With Rules Engine (serverless, automatic):
  Device → IoT Core → Rules Engine → DynamoDB ← AUTO! No server needed!
                                   → Lambda   ← AUTO! Runs only when triggered
                                   → SNS      ← AUTO! Sends push notification
```

A Rule looks like this (human readable version):
```
IF a message arrives on topic: vdb/+/+/evt
THEN:
  → Save the message to DynamoDB table "vdb-event-logs"
  → Also trigger Lambda function "process-visitor-event"
```

The actual rule uses a simple SQL-like query:
```sql
SELECT topic(3) as device_id, * FROM 'vdb/+/+/evt'
```
(`topic(3)` extracts the 3rd part of the topic path = your device_id)

**Real-world example in your VDB system:**
```
1. Visitor presses button on VDB
2. Ameba Pro publishes to:  vdb/sandbox_001/vdb-001/evt
   Payload: { msg_type: "visitor.button_press", ... }
3. Rules Engine fires:
   → Stores event in DynamoDB (visitor log)
   → Triggers Lambda → Lambda calls SNS → Push notification to mobile app
All of this happens in < 200ms, automatically, with no server.
```

---

### Q3: Can Topics and Payloads Be Changed Later?

**Yes, completely.** Topics are just strings. Payloads are just JSON. Nothing is locked in.

```
What CAN be changed at any time:
  ✅ Topic names (e.g. rename evt → events)
  ✅ Payload field names (e.g. rename msg_type → type)
  ✅ Add new fields to any payload
  ✅ Add new msg_type values (e.g. add detection.drone)
  ✅ Remove fields you don't end up using
  ✅ Change QoS levels per topic
  ✅ Change retain settings

What requires updating when you change:
  • IoT Policies — if you rename a topic, update the policy ARNs
  • Device firmware — update MQTT_TOPIC_CMD constant
  • Mobile app code — update the subscribe/publish calls
  • Rules Engine SQL — update the FROM 'old/topic' to new topic
  • DynamoDB queries — if you rename payload fields

The schema in your docs is a DESIGN BLUEPRINT, not a contract.
Think of it as the plan you start with, and refine as you go.
```

I'll update the documentation in this chat whenever you decide to change something.

---

### Q4: AWS Console vs AWS CLI — Which to Use?

**Decision: Console for learning (Phases 1-6), CLI for scripting later** ✅

```
AWS Console (Browser)                  AWS CLI (Terminal)
─────────────────────                  ──────────────────
✅ Visual — see what you're building   ✅ Fast, repeatable
✅ Instant feedback if you make error  ✅ Scriptable for automation
✅ Click to explore related resources  ✅ Easier for complex JSON policies
✅ Built-in MQTT test client           ✅ Good for bulk operations
✅ Better for learning what exists     ✅ Can be version-controlled (Git)
✅ No syntax errors in JSON             ⚠️  Easy to make typos in commands
✅ Guided forms with validation         ⚠️  No visual feedback

Our approach:
  Phases 1-3:  Console ONLY — see everything visually first
  Phases 4-6:  Console for setup + CLI for policies (JSON is easier in CLI)
  Phase 7+:    CLI/code — automation takes over
```

This guide keeps **both** — Console steps explained in words, CLI commands
as a backup (and for your reference/documentation).

---

---

## Implementation Phases Overview

```
Phase 1: AWS Account & IoT Core Setup          ← You are here
   └── Create IoT Core resources, understand the console

Phase 2: Create Your First "Thing" (Device)
   └── Register VDB device, create certificates, attach policy

Phase 3: Test with MQTT Test Client
   └── Publish/subscribe using AWS Console — no device needed!

Phase 4: IoT Policies (Your ACL Rules)
   └── Map your MQTT topic schema to IoT Core policies

Phase 5: Rules Engine — Route Messages to AWS Services
   └── Store events in DynamoDB, trigger Lambda, send push via SNS

Phase 6: Device Shadow — Track Device State
   └── Online/offline status, surveillance mode, lock state

Phase 7: Simulated Device (Python Script)
   └── Create a Python script that acts like your VDB device

Phase 8: Connect Real Realtek Ameba Pro Board
   └── Port the MQTT client to your actual hardware

Phase 9: App Integration (WebSocket MQTT)
   └── Connect mobile app via MQTT over WebSocket (WSS)

Phase 10: Monitoring, Alerts & Production Hardening
   └── CloudWatch dashboards, alarms, logging
```

---

## Phase 1: AWS Account & IoT Core Setup  ✅ COMPLETED

### Goal: Get your AWS sandbox account ready and verify IoT Core access

### What's a Sandbox Account?
A sandbox account = a real AWS account you use only for development/testing.
You create real AWS resources in it, but you don't put real users or production
data in it. It lets you experiment without fear of breaking anything important.
Free tier applies — cost is ~$0 for what we're building.

### Completed State
```
Account ID   : 211289421034
IAM User     : jinayg@godrej.com
Group        : Godrej-Administrator-Access (AdministratorAccess policy)
Region       : ap-south-1 (Mumbai)
IoT Endpoint : a2d7mswwxh8eti-ats.iot.ap-south-1.amazonaws.com
AWS CLI      : v2.33.24 — configured and working on Raspberry Pi
```

---

### Step 1.1 — Create AWS Access Keys

> **Why?** Your computer needs "keys" to talk to AWS from the terminal. It's like
> a username+password but for programmatic access.

**In the AWS Console (browser):**
1. Go to: https://console.aws.amazon.com/iam/
2. Click your **account name (top right) → Security credentials**
3. Scroll to **"Access keys"** → Click **"Create access key"**
4. Select **"Command Line Interface (CLI)"** → Check the confirmation → Next
5. Description: `vdb-dev` → Click **Create**
6. **COPY BOTH KEYS NOW** — you can never see the Secret again!
   - Access Key ID: `AKIA...`
   - Secret Access Key: `...`

---

### Step 1.2 — Configure AWS CLI

> AWS CLI is already installed on this machine. Now we configure it with your keys.

```bash
aws configure
```

It will ask 4 questions:
```
AWS Access Key ID:      ← Paste your Access Key ID from Step 1.1
AWS Secret Access Key:  ← Paste your Secret Access Key from Step 1.1
Default region name:    ← Type: ap-south-1   (or us-east-1 if outside India)
Default output format:  ← Type: json
```

> **What is a region?** AWS has data centers in many locations worldwide. A
> region is one location (e.g. Mumbai = ap-south-1). All your resources
> (IoT devices, databases, etc.) live in the region you pick. Pick one and
> stick with it — mixing regions adds complexity.

---

### Step 1.3 — Verify Everything Works
```bash
# This should print your account number and user name
aws sts get-caller-identity
```

Expected output (your numbers will be different):
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```
If you see this → ✅ CLI is working

### Step 1.4 — Get Your IoT Core Endpoint

> **What is this?** Every AWS account gets a unique MQTT broker URL.
> This is the address your VDB device and app will connect to.
> It never changes for your account.

```bash
aws iot describe-endpoint --endpoint-type iot:Data-ATS
```

Expected output:
```json
{
    "endpointAddress": "xxxxxxxxxxxxxx-ats.iot.ap-south-1.amazonaws.com"
}
```

**Save this endpoint address!** It's your MQTT broker URL. Format: `[random]-ats.iot.[region].amazonaws.com`

The `-ats` means "Amazon Trust Services" — it uses Amazon's own SSL certificate
authority instead of a third party. Always use the `-ats` endpoint (not the older
legacy endpoint).

---

### Step 1.5 — Explore the IoT Core Console (Just Look)

> Before creating anything, spend 5 minutes exploring. You'll understand what
> you're building when you can see where it lives.

1. Go to: **https://console.aws.amazon.com/iot/**
2. Make sure you're in the right region (top-right corner of console)
3. Explore these sections — **just click around, don't create anything yet:**

```
Left sidebar:
├── Manage
│   ├── All devices → Things      ← Your VDB devices will appear here
│   ├── Thing types               ← Templates for device types (e.g. "VDB")
│   └── Thing groups              ← Organize devices by tenant/location
├── Security
│   ├── Certificates              ← Files that prove device identity
│   └── Policies                  ← ACL rules — what each device can publish/subscribe
├── Message Routing
│   └── Rules                     ← Rules Engine lives here
├── Shadow                        ← Device state storage
└── Test
    └── MQTT test client          ← ⭐ YOUR BEST FRIEND for testing!
```

> **Tip**: The MQTT Test Client in the console IS a real MQTT client connected
> to your broker. When you publish from it, real devices receive it. When
> devices publish, you see it instantly. No extra software needed.

---

## Phase 2: Create Your First "Thing" (Device)  ✅ COMPLETED

### Goal: Register your VDB device in IoT Core with certificates

### Key Concepts (Simplified)
```
Thing        = Your VDB device (a record in AWS that says "this device exists")
Certificate  = A file your device uses to prove its identity (like a passport)
Policy       = Rules that say what the device can publish/subscribe to (your ACLs)
```

### Decisions Made
```
Thing type name  : realtek              (named after the Realtek chip family)
Device name      : vdb-sandbox-001
Group            : vdb-devices          (Things go HERE directly — no tenant subgroup)
Device Shadow    : Unnamed (classic)    (one shadow per device — simple, sufficient)
tenant_id        : sandbox_001          (Thing attribute + MQTT topic string only,
                                         no AWS group needed for this)
Tags everywhere  : project=realtek
                   environment=dev
```

### Why tenant_id is NOT a group
```
Thing Group  →  Just for organizing devices in the AWS Console visually.
                Does NOT affect MQTT topics or message routing.

MQTT Topic   →  vdb/sandbox_001/vdb-sandbox-001/evt
                     ↑
                     This is just a string in the topic path.
                     It exists for ACL policy rules and routing only.
                     It does NOT need a matching Thing Group.

So: put Things directly in vdb-devices group.
    Keep sandbox_001 in topics and as a Thing attribute.
    Add tenant subgroups only when you have real multi-tenant customers.
```

### Completed State
```
AWS IoT Core (ap-south-1)
├── Thing Type  : realtek  [project=realtek, environment=dev]
│   └── Searchable attributes: firmware_version, hardware_version
├── Thing Group : vdb-devices  [project=realtek, environment=dev]
├── Thing       : vdb-sandbox-001
│   ├── Type        : realtek
│   ├── Group       : vdb-devices
│   ├── Shadow      : Unnamed (classic)
│   └── Attributes
│       ├── firmware_version = 1.0.0          (searchable)
│       ├── hardware_version = ameba_amb82_mini (searchable)
│       ├── tenant_id        = sandbox_001     (regular)
│       └── device_name      = front_door_dev  (regular)
├── Certificate : 9b8772b187b2...b0e037  (ACTIVE)
│   └── Attached to: vdb-sandbox-001
├── Policy      : vdb-sandbox-device-policy
│   ├── Connect  → client/vdb-*
│   ├── Publish  → vdb/sandbox_001/*/evt|telemetry|status
│   ├── Subscribe→ vdb/sandbox_001/*/cmd + vdb/system/broadcast
│   └── Receive  → vdb/sandbox_001/*/cmd + vdb/system/broadcast
└── Endpoint    : a2d7mswwxh8eti-ats.iot.ap-south-1.amazonaws.com
```

### Certificate Files (saved on Raspberry Pi)
```
~/vdb-certs/
├── vdb-sandbox-001.cert.pem      ← device certificate (identity)
├── vdb-sandbox-001.private.key   ← SECRET — never share/commit to Git
├── vdb-sandbox-001.public.key    ← public key
└── AmazonRootCA1.pem             ← AWS root CA (device uses to trust AWS)

Original downloads kept in:
~/Downloads/iotcore_certs/        ← original filenames with hash prefix
```

> **Certificate ID**: `9b8772b187b29d9cdf4b6119d50ad15e7080c42898ad426218fc935a32b0e037`
> This is the unique ID AWS uses. You can find it in Console → Security → Certificates.

---

### Step 2.1 — Create Thing Type  ✅ DONE

Created in console with:
- Name: `realtek`
- Description: `Video Doorbell Device`
- Searchable attributes: `firmware_version`, `hardware_version`
- Tags: `project=realtek`, `environment=dev`

CLI reference (for documentation):
```bash
aws iot create-thing-type \
  --thing-type-name "realtek" \
  --thing-type-properties '{
    "thingTypeDescription": "Video Doorbell Device",
    "searchableAttributes": ["firmware_version", "hardware_version"]
  }' \
  --tags '[{"Key":"project","Value":"realtek"},{"Key":"environment","Value":"dev"}]'
```

### Step 2.2 — Create Thing Group  ✅ DONE

Created in console:
- Group name: `vdb-devices`
- Parent group: none (root group)
- Tags: `project=realtek`, `environment=dev`

CLI reference:
```bash
aws iot create-thing-group \
  --thing-group-name "vdb-devices" \
  --tags '[{"Key":"project","Value":"realtek"},{"Key":"environment","Value":"dev"}]'
```

### Step 2.3 — Register Device (Thing)  ✅ DONE

Created in console with:
- Thing name: `vdb-sandbox-001`
- Thing type: `realtek`
- Device Shadow: `Unnamed (classic)`
- Searchable attributes (from `realtek` type):
  - `firmware_version` = `1.0.0`
  - `hardware_version` = `ameba_amb82_mini`
- Regular attributes:
  - `tenant_id` = `sandbox_001`      ← used by IoT Policy at connect time
  - `device_name` = `front_door_dev`
- Thing group: `vdb-devices`
- Tags: `project=realtek`, `environment=dev`

> **device_name uses underscore** — spaces not allowed in attribute values.

> **Unnamed shadow (classic)** chosen over Named shadow because we only need
> one state document per device for now (mode, battery, lock state, online/offline).
> Named shadows can be added later if different parts of the app need isolated state.

CLI reference:
```bash
aws iot create-thing \
  --thing-name "vdb-sandbox-001" \
  --thing-type-name "realtek" \
  --attribute-payload '{
    "attributes": {
      "tenant_id": "sandbox_001",
      "device_name": "front_door_dev",
      "firmware_version": "1.0.0",
      "hardware_version": "ameba_amb82_mini"
    }
  }'

aws iot add-thing-to-thing-group \
  --thing-group-name "vdb-devices" \
  --thing-name "vdb-sandbox-001"
```

### Step 2.4 — Create Certificate  ✅ DONE

Selected **"Auto-generate a new certificate"** during the Create Thing flow.

```
Certificate ID : 9b8772b187b29d9cdf4b6119d50ad15e7080c42898ad426218fc935a32b0e037
Status         : ACTIVE
Attached to    : vdb-sandbox-001
```

> **Why auto-generate?** AWS creates the cert + key pair. Simplest option for
> sandbox. For production factory provisioning, you'd use "Upload CSR" so the
> private key is generated on the device itself and never leaves it.

> **Certificate options explained:**
> - Auto-generate → AWS makes cert + keys. Use for sandbox. ✅
> - Use my certificate → You have your own CA already. Not applicable here.
> - Upload CSR → You generate keys on device, send only public part to AWS to sign.
>   More secure for production. Relevant later for Ameba board provisioning.
> - Skip → Device can't connect to MQTT. Never skip.

### Step 2.5 — Create IoT Policy  ✅ DONE

Created via **Security → Policies → Create policy** (opened in new tab from thing creation flow).

- Policy name: `vdb-sandbox-device-policy`
- Created using JSON tab

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iot:Connect",
      "Resource": "arn:aws:iot:ap-south-1:211289421034:client/vdb-*"
    },
    {
      "Effect": "Allow",
      "Action": "iot:Publish",
      "Resource": [
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/sandbox_001/*/evt",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/sandbox_001/*/telemetry",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/sandbox_001/*/status"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "iot:Subscribe",
      "Resource": [
        "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/sandbox_001/*/cmd",
        "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/system/broadcast"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "iot:Receive",
      "Resource": [
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/sandbox_001/*/cmd",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/system/broadcast"
      ]
    }
  ]
}
```

> **Policy explained:**
> - `Connect` → any client ID starting with `vdb-` can connect
> - `Publish` → device sends TO cloud: evt, telemetry, status topics only
> - `Subscribe` → device registers interest in: cmd and broadcast topics
> - `Receive` → device actually gets subscribed messages (AWS needs both
>   Subscribe AND Receive — Subscribe opens the channel, Receive lets
>   messages flow through. Without Receive, messages are silently dropped.)
> - `*` in topic paths = wildcard for any device ID in this tenant

### Step 2.6 — Attach Policy + Download Certificates  ✅ DONE

Policy `vdb-sandbox-device-policy` attached to certificate during Thing creation flow.

Files downloaded and saved:
```bash
# Original location (with AWS hash prefix filenames):
~/Downloads/iotcore_certs/

# Clean copies (use these everywhere from now on):
~/vdb-certs/flutter-app-sandbox-001.cert.pem      ← device certificate
~/vdb-certs/flutter-app-sandbox-001.private.key   ← SECRET — never share or commit to Git
~/vdb-certs/vdb-sandbox-001.public.key    ← public key
~/vdb-certs/AmazonRootCA1.pem             ← AWS root CA
```

To copy with clean names (run once if not done yet):
```bash
mkdir -p ~/vdb-certs
cd ~/Downloads/iotcore_certs
HASH="9b8772b187b29d9cdf4b6119d50ad15e7080c42898ad426218fc935a32b0e037"
cp "${HASH}-certificate.pem.crt" ~/vdb-certs/flutter-app-sandbox-001.cert.pem
cp "${HASH}-private.pem.key"     ~/vdb-certs/flutter-app-sandbox-001.private.key
cp "${HASH}-public.pem.key"      ~/vdb-certs/vdb-sandbox-001.public.key
cp "AmazonRootCA1.pem"           ~/vdb-certs/AmazonRootCA1.pem
```

### Step 2.7 — Verify Everything is Linked  ✅ DONE

Verified in console — **Manage → Things → vdb-sandbox-001**:
- **Thing groups** tab → shows `vdb-devices` ✅
- **Certificates** tab → shows certificate `9b8772...` ACTIVE ✅
- Certificate → **Policies** tab → shows `vdb-sandbox-device-policy` ✅

---
```
AWS IoT Core (ap-south-1)
├── Thing Type : realtek  [project=realtek, environment=dev]
├── Thing Group: vdb-devices  [project=realtek, environment=dev]
├── Thing      : vdb-sandbox-001
│   ├── Type      : realtek
│   ├── Group     : vdb-devices
│   └── Attributes: tenant_id=sandbox_001, firmware_version=1.0.0, ...
├── Certificate: attached to vdb-sandbox-001 (ACTIVE)
├── Policy     : vdb-sandbox-device-policy
│   ├── Connect  → client/vdb-*
│   ├── Publish  → vdb/sandbox_001/*/evt|telemetry|status
│   ├── Subscribe→ vdb/sandbox_001/*/cmd + vdb/system/broadcast
│   └── Receive  → vdb/sandbox_001/*/cmd + vdb/system/broadcast
└── Endpoint   : a2d7mswwxh8eti-ats.iot.ap-south-1.amazonaws.com
```

---

## Phase 3: Test with MQTT Test Client  ✅ COMPLETED

### Goal: Verify your topic schema works using the AWS Console — no device needed!

### Step 3.1 — Open MQTT Test Client  ✅ DONE

Opened at: **AWS Console → IoT Core → Test → MQTT Test Client**

### Step 3.2 — Subscribe to Device Topics  ✅ DONE

Subscribed to:
```
vdb/sandbox_001/vdb-sandbox-001/#
```
Single wildcard subscription catches ALL messages for the device.

### Step 3.3 — Publish a Test Command  ✅ DONE

**Topic**: `vdb/sandbox_001/vdb-sandbox-001/cmd`

**Message published and confirmed received:**
```json
{
  "msg_type": "lock.unlock",
  "msg_id": "test-001",
  "timestamp": 1741564800000,
  "source": "app",
  "payload": {
    "reason": "manual",
    "timeout_ms": 5000
  }
}
```

### Step 3.4 — Test All Topic Types  ✅ DONE

All 4 topic types published and confirmed appearing in the subscription panel.

**Event Topic**: `vdb/sandbox_001/vdb-sandbox-001/evt`
```json
{
  "msg_type": "visitor.button_press",
  "event_id": "evt-test-001",
  "timestamp": 1741564800000,
  "priority": "high",
  "payload": {
    "snapshot_url": "https://example.com/snapshot.jpg",
    "face_recognition": {
      "attempted": true,
      "status": "pending"
    }
  }
}
```

**Telemetry Topic**: `vdb/sandbox_001/vdb-sandbox-001/telemetry`
```json
{
  "msg_type": "metrics.batch",
  "timestamp": 1741564800000,
  "interval_sec": 30,
  "metrics": {
    "health": {
      "battery_level": 85,
      "cpu_temp": 45.5,
      "memory_used_mb": 320
    },
    "connectivity": {
      "wifi_rssi": -65,
      "mqtt_connected": true
    }
  }
}
```

**Status Topic** (retained): `vdb/sandbox_001/vdb-sandbox-001/status`
```json
{
  "timestamp": 1741564800000,
  "connection": {
    "status": "online",
    "firmware_version": "1.0.0"
  },
  "operational": {
    "mode": "surveillance",
    "features": {
      "surveillance": true,
      "face_recognition": true
    }
  }
}
```

**Notification Topic**: `vdb/sandbox_001/user/user_test/notify`
```json
{
  "msg_type": "visitor",
  "notification_id": "notif-test-001",
  "timestamp": 1741564800000,
  "priority": "high",
  "device_id": "vdb-sandbox-001",
  "device_name": "Front Door Dev",
  "payload": {
    "type": "button_press",
    "title": "Visitor at Front Door",
    "body": "Someone pressed the doorbell"
  }
}
```

### Step 3.5 — Verify Wildcard Subscriptions  ✅ DONE

Confirmed all wildcard patterns work:
```
vdb/sandbox_001/+/evt          ← Events from ALL devices in this tenant
vdb/sandbox_001/+/#            ← ALL messages from ALL devices in this tenant
vdb/#                          ← EVERYTHING (cloud backend pattern)
```

---

## POC Demo Handoff — sandbox_001  ✅ COMPLETED (March 10, 2026)

> Phase 4+ (dynamic policy variables, multi-tenant, onboarding flow) is deferred.
> Everything below is hardcoded for `sandbox_001` / `vdb-sandbox-001` for the POC demo.

### AWS Resources Created for POC

```
IoT Endpoint : a2d7mswwxh8eti-ats.iot.ap-south-1.amazonaws.com
Port         : 8883
Protocol     : MQTT 3.1.1 over TLS
Region       : ap-south-1

Thing        : vdb-sandbox-001
Tenant ID    : sandbox_001
Device Cert  : 9b8772b187b29d9cdf4b6119d50ad15e7080c42898ad426218fc935a32b0e037
Device Policy: vdb-sandbox-device-policy

App Cert     : c31b67b3f77666828db44bac6ce116fd808514c7e96b98522a97b6ba74b15d03
App Policy   : vdb-sandbox-app-policy
```

---

### Hardware Dev Handoff (Realtek AMB82 Mini)

**Files to hand over** (from `~/Downloads/iotcore_certs/`):
```
vdb-sandbox-001.cert.pem      ← device certificate
vdb-sandbox-001.private.key   ← SECRET — never share publicly or commit to Git
AmazonRootCA1.pem             ← AWS root CA
```

**Connection parameters:**
```
Endpoint  : a2d7mswwxh8eti-ats.iot.ap-south-1.amazonaws.com
Port      : 8883
Client ID : vdb-sandbox-001
Protocol  : MQTT 3.1.1 over TLS
Library   : AmebaAWSIoTClient (built into Ameba Arduino SDK)
```

**What the firmware must do:**

| Event | Topic | Direction |
|-------|-------|-----------|
| Board connects | `vdb/sandbox_001/vdb-sandbox-001/status` | Publish |
| Board disconnects (LWT) | `vdb/sandbox_001/vdb-sandbox-001/status` | Auto (LWT) |
| Doorbell button press | `vdb/sandbox_001/vdb-sandbox-001/evt` | Publish |
| Periodic health metrics | `vdb/sandbox_001/vdb-sandbox-001/telemetry` | Publish every 30s |
| Receive app commands | `vdb/sandbox_001/vdb-sandbox-001/cmd` | Subscribe |

**Minimum payloads for demo:**

On connect — publish to `status`:
```json
{ "status": "online", "firmware_version": "1.0.0" }
```

LWT — set at connect time (AWS publishes this automatically if board drops):
```
Topic   : vdb/sandbox_001/vdb-sandbox-001/status
Payload : { "status": "offline" }
Retain  : true
QoS     : 1
```

Button press — publish to `evt`:
```json
{
  "msg_type": "visitor.button_press",
  "event_id": "evt-001",
  "timestamp": 1741564800000
}
```

---

### App Dev Handoff (Flutter)

**Files to hand over** (from `~/Downloads/iotcore_certs/`):
```
flutter-app-sandbox-001.cert.pem      ← app certificate
flutter-app-sandbox-001.private.key   ← SECRET
AmazonRootCA1.pem                     ← AWS root CA
```

> The app uses its OWN certificate — never use the device cert in the app.

**Connection parameters:**
```
Endpoint  : a2d7mswwxh8eti-ats.iot.ap-south-1.amazonaws.com
Port      : 8883
Client ID : flutter-app-sandbox-001   (must start with flutter-app-)
Protocol  : MQTT 3.1.1 over TLS
Package   : mqtt_client (pub.dev)
```

**What the app must do:**

| Action | Topic | Direction |
|--------|-------|-----------|
| Show doorbell events | `vdb/sandbox_001/vdb-sandbox-001/evt` | Subscribe |
| Show device online/offline | `vdb/sandbox_001/vdb-sandbox-001/status` | Subscribe |
| Show health metrics | `vdb/sandbox_001/vdb-sandbox-001/telemetry` | Subscribe |
| Send unlock command | `vdb/sandbox_001/vdb-sandbox-001/cmd` | Publish |

**Flutter integration snippet** (`mqtt_client: ^10.x.x`):
```dart
final client = MqttServerClient.withPort(
  'a2d7mswwxh8eti-ats.iot.ap-south-1.amazonaws.com',
  'flutter-app-sandbox-001',
  8883
);
client.secure = true;
client.securityContext = SecurityContext.defaultContext
  ..useCertificateChain('flutter-app-sandbox-001.cert.pem')
  ..usePrivateKey('flutter-app-sandbox-001.private.key')
  ..setTrustedCertificates('AmazonRootCA1.pem');

// Subscribe on connect
client.subscribe('vdb/sandbox_001/vdb-sandbox-001/#', MqttQos.atLeastOnce);

// Send unlock command
final builder = MqttClientPayloadBuilder()
  ..addString('{"msg_type":"lock.unlock","msg_id":"cmd-001","source":"app","payload":{"reason":"manual","timeout_ms":5000}}');
client.publishMessage(
  'vdb/sandbox_001/vdb-sandbox-001/cmd',
  MqttQos.atLeastOnce,
  builder.payload!
);
```

---

## Phase 4: IoT Policies (Your ACL Rules — Properly Mapped)  ✅ COMPLETED

### Completed State
```
vdb-device-policy-v2       → dynamic device policy (policy variables, all new devices use this)
vdb-app-policy-v2          → dynamic app policy (any tenant, v2 is active — typo in v1 fixed)
vdb-cloud-backend-policy   → backend/Lambda full access policy

POC policies (still active, sandbox-001 uses these):
vdb-sandbox-device-policy  → hardcoded sandbox_001 device policy
vdb-sandbox-app-policy     → hardcoded sandbox_001 app policy
```

> `vdb-sandbox-001` deliberately kept on old hardcoded policies for POC demo stability.
> New devices from here on get `vdb-device-policy-v2`.

### Step 4.1 — Device Policy (dynamic)  ✅ DONE

Created `vdb-device-policy-v2` — uses IoT policy variables so one policy covers every device:

- `${iot:Connection.Thing.ThingName}` → resolves to the connecting device's Thing name
- `${iot:Connection.Thing.Attributes[tenant_id]}` → resolves to the `tenant_id` attribute set on that Thing
- `Condition: IsAttached: true` → device MUST be a registered Thing with a cert attached; bare certs rejected

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowConnect",
      "Effect": "Allow",
      "Action": "iot:Connect",
      "Resource": "arn:aws:iot:ap-south-1:211289421034:client/${iot:Connection.Thing.ThingName}",
      "Condition": { "Bool": { "iot:Connection.Thing.IsAttached": "true" } }
    },
    {
      "Sid": "AllowDevicePublish",
      "Effect": "Allow",
      "Action": "iot:Publish",
      "Resource": [
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/${iot:Connection.Thing.Attributes[tenant_id]}/${iot:Connection.Thing.ThingName}/evt",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/${iot:Connection.Thing.Attributes[tenant_id]}/${iot:Connection.Thing.ThingName}/telemetry",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/${iot:Connection.Thing.Attributes[tenant_id]}/${iot:Connection.Thing.ThingName}/status"
      ]
    },
    {
      "Sid": "AllowDeviceSubscribe",
      "Effect": "Allow",
      "Action": "iot:Subscribe",
      "Resource": [
        "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/${iot:Connection.Thing.Attributes[tenant_id]}/${iot:Connection.Thing.ThingName}/cmd",
        "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/system/broadcast"
      ]
    },
    {
      "Sid": "AllowDeviceReceive",
      "Effect": "Allow",
      "Action": "iot:Receive",
      "Resource": [
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/${iot:Connection.Thing.Attributes[tenant_id]}/${iot:Connection.Thing.ThingName}/cmd",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/system/broadcast"
      ]
    }
  ]
}
```

### Step 4.2 — App Policy (dynamic)  ✅ DONE

Created `vdb-app-policy-v2` (v2 active — v1 had a typo in account ID, fixed via new version):
- App can connect with any `flutter-app-*` client ID
- Can publish commands to any tenant's any device
- Can subscribe/receive evt, status, telemetry, notify from any tenant

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "AllowConnect", "Effect": "Allow", "Action": "iot:Connect",
      "Resource": "arn:aws:iot:ap-south-1:211289421034:client/flutter-app-*" },
    { "Sid": "AllowAppPublishCommands", "Effect": "Allow", "Action": "iot:Publish",
      "Resource": "arn:aws:iot:ap-south-1:211289421034:topic/vdb/+/+/cmd" },
    { "Sid": "AllowAppSubscribe", "Effect": "Allow", "Action": "iot:Subscribe",
      "Resource": [
        "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/+/+/evt",
        "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/+/+/status",
        "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/+/+/telemetry",
        "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/+/user/+/notify",
        "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/system/broadcast"
      ]
    },
    { "Sid": "AllowAppReceive", "Effect": "Allow", "Action": "iot:Receive",
      "Resource": [
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/+/+/evt",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/+/+/status",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/+/+/telemetry",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/+/user/+/notify",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/system/broadcast"
      ]
    }
  ]
}
```

### Step 4.3 — Cloud Backend Policy  ✅ DONE

Created `vdb-cloud-backend-policy` — used by Lambda functions and backend services:
- Full publish access: cmd, notify, broadcast to any tenant/device
- Full subscribe + receive: entire `vdb/#` tree (needed to process all device events)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "AllowConnect", "Effect": "Allow", "Action": "iot:Connect",
      "Resource": "arn:aws:iot:ap-south-1:211289421034:client/cloud-backend-*" },
    { "Sid": "AllowCloudPublish", "Effect": "Allow", "Action": "iot:Publish",
      "Resource": [
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/+/+/cmd",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/+/user/+/notify",
        "arn:aws:iot:ap-south-1:211289421034:topic/vdb/system/broadcast"
      ]
    },
    { "Sid": "AllowCloudSubscribe", "Effect": "Allow", "Action": "iot:Subscribe",
      "Resource": "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/#" },
    { "Sid": "AllowCloudReceive", "Effect": "Allow", "Action": "iot:Receive",
      "Resource": "arn:aws:iot:ap-south-1:211289421034:topic/vdb/*" }
  ]
}
```

### Policy Summary — All Policies in Account

| Policy | Used by | Scope |
|--------|---------|-------|
| `vdb-sandbox-device-policy` | `vdb-sandbox-001` cert (POC) | Hardcoded sandbox_001 |
| `vdb-sandbox-app-policy` | Flutter app cert (POC) | Hardcoded sandbox_001 |
| `vdb-device-policy-v2` | All new device certs | Dynamic — any tenant/device |
| `vdb-app-policy-v2` | All new app certs | Dynamic — any tenant/device |
| `vdb-cloud-backend-policy` | Lambda / backend | Full vdb/# access |

---

### Key Difference: IoT Core Policies vs Traditional ACLs
```
Traditional ACL:                     AWS IoT Core Policy:
  SUBSCRIBE: topic/filter    →        Action: iot:Subscribe + Resource: topicfilter/...
  PUBLISH: topic             →        Action: iot:Publish + Resource: topic/...
  (implicit receive)         →        Action: iot:Receive + Resource: topic/...  ← EXTRA!
```

**AWS IoT Core requires BOTH `iot:Subscribe` AND `iot:Receive`** for a device to get messages.

### Step 4.1 — Device Policy (Production-grade, uses Thing attributes)

> This upgrades `vdb-sandbox-device-policy` with stricter per-device scoping.
> Instead of `*` wildcards for device IDs, it uses AWS policy variables that
> auto-fill from the Thing's own attributes at connection time.

```bash
aws iot create-policy \
  --policy-name "vdb-device-policy-v2" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowConnect",
        "Effect": "Allow",
        "Action": "iot:Connect",
        "Resource": "arn:aws:iot:ap-south-1:211289421034:client/${iot:Connection.Thing.ThingName}",
        "Condition": {
          "Bool": {
            "iot:Connection.Thing.IsAttached": "true"
          }
        }
      },
      {
        "Sid": "AllowDevicePublish",
        "Effect": "Allow",
        "Action": "iot:Publish",
        "Resource": [
          "arn:aws:iot:ap-south-1:211289421034:topic/vdb/${iot:Connection.Thing.Attributes[tenant_id]}/${iot:Connection.Thing.ThingName}/evt",
          "arn:aws:iot:ap-south-1:211289421034:topic/vdb/${iot:Connection.Thing.Attributes[tenant_id]}/${iot:Connection.Thing.ThingName}/telemetry",
          "arn:aws:iot:ap-south-1:211289421034:topic/vdb/${iot:Connection.Thing.Attributes[tenant_id]}/${iot:Connection.Thing.ThingName}/status"
        ]
      },
      {
        "Sid": "AllowDeviceSubscribe",
        "Effect": "Allow",
        "Action": "iot:Subscribe",
        "Resource": [
          "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/${iot:Connection.Thing.Attributes[tenant_id]}/${iot:Connection.Thing.ThingName}/cmd",
          "arn:aws:iot:ap-south-1:211289421034:topicfilter/vdb/system/broadcast"
        ]
      },
      {
        "Sid": "AllowDeviceReceive",
        "Effect": "Allow",
        "Action": "iot:Receive",
        "Resource": [
          "arn:aws:iot:ap-south-1:211289421034:topic/vdb/${iot:Connection.Thing.Attributes[tenant_id]}/${iot:Connection.Thing.ThingName}/cmd",
          "arn:aws:iot:ap-south-1:211289421034:topic/vdb/system/broadcast"
        ]
      }
    ]
  }'
```

**What this policy does (upgrade from sandbox policy):**
- Device can ONLY connect with its own Thing name as client ID (not any `vdb-*`)
- Device can ONLY publish to its OWN topics (not any device in the tenant)
- `${iot:Connection.Thing.Attributes[tenant_id]}` → AWS reads the `tenant_id`
  attribute from the Thing record and substitutes it automatically. So
  `vdb-sandbox-001` with `tenant_id=sandbox_001` can only publish to
  `vdb/sandbox_001/vdb-sandbox-001/evt` — not any other device's topics.

### Step 4.2 — App/User Policy (Mobile App)
```bash
aws iot create-policy \
  --policy-name "vdb-app-user-policy" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowConnect",
        "Effect": "Allow",
        "Action": "iot:Connect",
        "Resource": "arn:aws:iot:*:*:client/app-*"
      },
      {
        "Sid": "AllowAppPublishCommands",
        "Effect": "Allow",
        "Action": "iot:Publish",
        "Resource": "arn:aws:iot:*:*:topic/vdb/sandbox_001/*/cmd"
      },
      {
        "Sid": "AllowAppSubscribeWildcard",
        "Effect": "Allow",
        "Action": "iot:Subscribe",
        "Resource": [
          "arn:aws:iot:*:*:topicfilter/vdb/sandbox_001/+/#",
          "arn:aws:iot:*:*:topicfilter/vdb/sandbox_001/user/*/notify",
          "arn:aws:iot:*:*:topicfilter/vdb/system/broadcast"
        ]
      },
      {
        "Sid": "AllowAppReceive",
        "Effect": "Allow",
        "Action": "iot:Receive",
        "Resource": [
          "arn:aws:iot:*:*:topic/vdb/sandbox_001/*",
          "arn:aws:iot:*:*:topic/vdb/system/broadcast"
        ]
      }
    ]
  }'
```

### Step 4.3 — Cloud Backend Policy (Lambda/EC2)
```bash
aws iot create-policy \
  --policy-name "vdb-cloud-backend-policy" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowConnect",
        "Effect": "Allow",
        "Action": "iot:Connect",
        "Resource": "arn:aws:iot:*:*:client/cloud-backend-*"
      },
      {
        "Sid": "AllowCloudPublish",
        "Effect": "Allow",
        "Action": "iot:Publish",
        "Resource": [
          "arn:aws:iot:*:*:topic/vdb/*/+/cmd",
          "arn:aws:iot:*:*:topic/vdb/*/user/+/notify",
          "arn:aws:iot:*:*:topic/vdb/system/broadcast"
        ]
      },
      {
        "Sid": "AllowCloudSubscribe",
        "Effect": "Allow",
        "Action": "iot:Subscribe",
        "Resource": "arn:aws:iot:*:*:topicfilter/vdb/#"
      },
      {
        "Sid": "AllowCloudReceive",
        "Effect": "Allow",
        "Action": "iot:Receive",
        "Resource": "arn:aws:iot:*:*:topic/vdb/*"
      }
    ]
  }'
```

### Policy Mapping Summary
```
Your MQTT Schema ACL              →  AWS IoT Core Policy
─────────────────────────────         ──────────────────────
Device SUBSCRIBE: cmd              →  iot:Subscribe topicfilter + iot:Receive topic
Device PUBLISH: evt/telemetry/#    →  iot:Publish topic (each listed)
App SUBSCRIBE: device/#            →  iot:Subscribe topicfilter + iot:Receive topic
App PUBLISH: cmd                   →  iot:Publish topic
Cloud SUBSCRIBE: vdb/#             →  iot:Subscribe topicfilter + iot:Receive topic
Cloud PUBLISH: cmd/notify          →  iot:Publish topic (each listed)
```

---

## Phase 5: Rules Engine — Route Messages to AWS Services  ✅ COMPLETED

### Completed State
```
DynamoDB Tables:
  vdb-events           → PK: device_id (S), SK: timestamp (S)  — event log, all devices
  vdb-device-status    → PK: device_id (S), no sort key        — latest state per device

S3 Bucket:
  vdb-media-211289421034  (ap-south-1, private, SSE-S3)

IAM Role:
  vdb-lambda-role      → AmazonDynamoDBFullAccess, AWSIoTFullAccess,
                          AmazonS3FullAccess, CloudWatchLogsFullAccess

Lambda Function:
  vdb-event-processor  → Python 3.14, role: vdb-lambda-role
                          handles both evt and status topic types

IoT Rules:
  vdb_evt_rule         → SQL: SELECT *, topic() AS topic FROM 'vdb/+/+/evt'
                          Action: Lambda → vdb-event-processor
  vdb_status_rule      → SQL: SELECT *, topic() AS topic FROM 'vdb/+/+/status'
                          Action: Lambda → vdb-event-processor
```

### Architecture Decision — Why Lambda over Direct DynamoDB Action

IoT Rules has a built-in **direct DynamoDB action** (no Lambda needed). We chose Lambda because:

- `evt` messages need transformation — timestamp epoch→ISO, null stripping, `extra` JSON building
- One Lambda handles both `evt` and `status` routing — single place to debug and extend
- Easy to add FCM notifications, Rekognition, deduplication later — just add lines
- CloudWatch logs every invocation — full visibility into what was written

**Future simplification option:**
- Keep Lambda for `vdb_evt_rule` (complex, needs transformation)
- Switch `vdb_status_rule` to direct DynamoDB action (simple flat overwrite, no transformation needed)

---

### Step 5.1 — Create DynamoDB Table `vdb-events`  ✅ DONE

Created in console — **DynamoDB → Tables → Create table**:
- Partition key: `device_id` (String)
- Sort key: `timestamp` (String)
- Settings: Default (PAY_PER_REQUEST billing)
- Tags: `project=realtek`, `environment=dev`

Row schema written by Lambda:
```
device_id     (PK)  :  "vdb-sandbox-001"
timestamp     (SK)  :  "2026-03-12T10:32:00.000Z"   ← ISO 8601, sortable
event_id            :  "evt-a1b2c3d4"
tenant_id           :  "sandbox_001"
event_type          :  "visitor.button_press"
message             :  "Visitor at front door"
snapshot_url        :  "https://vdb-media.s3.../snapshots/..."   ← S3 URL, not blob
extra               :  '{"face_matched": false}'
received_at         :  "2026-03-12T10:32:00.123Z"   ← server arrival time
```

> Images are NEVER stored in DynamoDB — only the S3 URL. Storing image blobs in DB hits
> the 1MB document limit, makes queries slow, and makes it expensive. DB stores the reference,
> S3 stores the file. App loads the list instantly from DynamoDB, lazy-loads images from S3 URL.

### Step 5.2 — Create DynamoDB Table `vdb-device-status`  ✅ DONE

Created in console:
- Partition key: `device_id` (String)
- No sort key — one row per device, always overwritten on new status message
- Tags: `project=realtek`, `environment=dev`

Row schema:
```
device_id         (PK)  :  "vdb-sandbox-001"
tenant_id               :  "sandbox_001"
status                  :  "online" | "offline"
firmware_version        :  "1.0.0"
last_seen               :  "2026-03-12T10:32:00.123Z"
```

### Step 5.3 — Create S3 Bucket  ✅ DONE

Created in console — `vdb-media-211289421034` (ap-south-1):
- Block all public access: ON
- Encryption: SSE-S3
- Tags: `project=realtek`, `environment=dev`

> Bucket name includes account ID because S3 names are globally unique across all AWS accounts.
> Images served via **pre-signed URLs** (time-limited, generated by Lambda per request) — bucket
> stays fully private, no public access ever needed.

S3 folder structure (auto-created on first upload):
```
vdb-media-211289421034/
  └── snapshots/
        └── {tenant_id}/{device_id}/{timestamp}.jpg
```

### Step 5.4 — Create IAM Role `vdb-lambda-role`  ✅ DONE

Created in console — **IAM → Roles → Create role**:
- Trusted entity: AWS service → Lambda
- Policies attached: AmazonDynamoDBFullAccess, AWSIoTFullAccess,
  AmazonS3FullAccess, CloudWatchLogsFullAccess
- Tags: `project=realtek`, `environment=dev`

> Full access policies used for sandbox simplicity. Tighten to specific table/bucket ARNs
> before production.

### Step 5.5 — Create Lambda Function `vdb-event-processor`  ✅ DONE

Created in console — **Lambda → Create function → Author from scratch**:
- Runtime: Python 3.14
- Execution role: `vdb-lambda-role`
- Tags: `project=realtek`, `environment=dev`

Function code:
```python
import json
import boto3
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb     = boto3.resource('dynamodb', region_name='ap-south-1')
events_table = dynamodb.Table('vdb-events')
status_table = dynamodb.Table('vdb-device-status')

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    # IoT Rule SQL (SELECT *, topic() AS topic) flattens the MQTT payload into event directly.
    # All top-level MQTT fields (msg_type, timestamp, event_id, status, etc.) are at event level.
    # The nested 'payload' object inside the MQTT message is accessible as event['payload'].
    topic      = event.get('topic', '')
    parts      = topic.split('/')

    if len(parts) != 4 or parts[0] != 'vdb':
        logger.error("Unexpected topic format: %s", topic)
        return {'statusCode': 400, 'body': 'Invalid topic format'}

    tenant_id  = parts[1]
    device_id  = parts[2]
    topic_type = parts[3]

    now_iso = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'

    timestamp = event.get('timestamp')
    if isinstance(timestamp, (int, float)):
        timestamp = datetime.fromtimestamp(timestamp / 1000, tz=timezone.utc) \
                            .strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
    if not timestamp:
        timestamp = now_iso

    if topic_type == 'evt':
        item = {
            'device_id'    : device_id,
            'timestamp'    : timestamp,
            'event_id'     : event.get('event_id', f"evt-{int(datetime.now(timezone.utc).timestamp()*1000)}"),
            'tenant_id'    : tenant_id,
            'event_type'   : event.get('msg_type', 'unknown'),       # top level ← fix
            'message'      : event.get('message', ''),               # top level
            'snapshot_url' : event.get('snapshot_url', None),        # top level
            'extra'        : json.dumps(event.get('payload', {})),   # nested payload = extra detail
            'received_at'  : now_iso,
        }
        item = {k: v for k, v in item.items() if v is not None and v != ''}
        events_table.put_item(Item=item)
        logger.info("Written to vdb-events: %s / %s / %s", device_id, event.get('msg_type'), timestamp)

    elif topic_type == 'status':
        item = {
            'device_id'        : device_id,
            'tenant_id'        : tenant_id,
            'status'           : event.get('status', 'unknown'),
            'firmware_version' : event.get('firmware_version', None),
            'last_seen'        : now_iso,
        }
        item = {k: v for k, v in item.items() if v is not None}
        status_table.put_item(Item=item)
        logger.info("Written to vdb-device-status: %s = %s", device_id, item.get('status'))

    else:
        logger.info("Topic type '%s' — no DB action configured", topic_type)

    return {'statusCode': 200, 'body': 'OK'}
```

### Step 5.6 — Create IoT Rule `vdb_evt_rule`  ✅ DONE

Created in console — **IoT Core → Message Routing → Rules → Create rule**:
- SQL: `SELECT *, topic() AS topic FROM 'vdb/+/+/evt'`
- SQL version: 2016-03-23
- Action: Lambda → `vdb-event-processor`
- Tags: `project=realtek`, `environment=dev`

> `topic()` is an IoT Core built-in that injects the full topic string into the payload
> so Lambda can extract `tenant_id` and `device_id` from the topic path.

### Step 5.7 — Create IoT Rule `vdb_status_rule`  ✅ DONE

Created in console:
- SQL: `SELECT *, topic() AS topic FROM 'vdb/+/+/status'`
- Action: Lambda → `vdb-event-processor`
- Tags: `project=realtek`, `environment=dev`

---

### Step 5.8 — Create Lambda `vdb-lifecycle-handler` for Offline Detection  ✅ DONE

**Problem:** When a device loses power or drops WiFi, it never publishes an `offline` status — IoT Rules only fire on messages received, not on disconnects. Need a separate mechanism to detect ungraceful disconnects.

**Solution:** IoT Core publishes an internal lifecycle event to `$aws/events/presence/disconnected/{clientId}` whenever any MQTT client disconnects. We route this through an IoT Rule to a Lambda that updates DynamoDB.

**File:** `/home/rayquaza/Documents/mqtt_system_design/vdb_lifecycle_handler.py`

Deployed via CLI:
```bash
zip /tmp/vdb_lifecycle_handler.zip vdb_lifecycle_handler.py
aws lambda create-function \
  --function-name vdb-lifecycle-handler \
  --runtime python3.14 \
  --role arn:aws:iam::211289421034:role/vdb-lambda-role \
  --handler vdb_lifecycle_handler.lambda_handler \
  --zip-file fileb:///tmp/vdb_lifecycle_handler.zip \
  --timeout 15 --memory-size 128 \
  --tags project=realtek,environment=dev \
  --region ap-south-1

# Grant IoT Rules Engine invoke permission
aws lambda add-permission \
  --function-name vdb-lifecycle-handler \
  --statement-id iot-lifecycle-invoke \
  --action lambda:InvokeFunction \
  --principal iot.amazonaws.com \
  --source-account 211289421034 \
  --region ap-south-1
```

**Lambda logic:**
1. Gets `clientId` from the lifecycle event (= `device_id`, e.g. `vdb-sandbox-001`)
2. Looks up `tenant_id` from `vdb-device-status` DynamoDB table
3. Updates `status = offline` + `last_seen` in DynamoDB
4. Publishes `{"status":"offline", "_src":"lifecycle"}` to `vdb/{tenant_id}/{device_id}/status` so live app MQTT subscribers are notified

**`_src: lifecycle` flag:** Prevents a processing loop — `vdb_status_rule` will fire again when the lifecycle handler publishes to the status topic, but `vdb-event-processor` checks for this flag and skips the DynamoDB write.

```
ARN: arn:aws:lambda:ap-south-1:211289421034:function:vdb-lifecycle-handler
```

---

### Step 5.9 — Create IoT Rule `vdb_lifecycle_rule`  ✅ DONE

Created in console:
- Rule name: `vdb_lifecycle_rule`
- SQL: `SELECT clientId, eventType, timestamp FROM '$aws/events/presence/disconnected/+'`
- SQL version: `2016-03-23`
- Action: Lambda → `vdb-lifecycle-handler`
- Tags: `project=realtek`, `environment=dev`

> **Note:** `$aws/events/presence/disconnected/+` is an internal IoT Core topic — it fires for **every** MQTT client that disconnects, not just your devices. The Lambda handles unknown `clientId`s gracefully (DynamoDB `get_item` returns nothing → early return).

**Verified end-to-end:**
```
Simulator connects   → publishes online status → vdb_status_rule → vdb-event-processor → DynamoDB: status=online  ✅
Simulator disconnects → IoT lifecycle event   → vdb_lifecycle_rule → vdb-lifecycle-handler → DynamoDB: status=offline ✅
```

---

## Phase 6: Device Shadow — Track Device State  ⏸ DEFERRED

> **Deferred decision (March 2026):** Shadow is not needed for the POC. Online/offline tracking is handled entirely by the `vdb-device-status` DynamoDB table (written by `vdb-event-processor` on connect, and `vdb-lifecycle-handler` on disconnect). Lock/unlock commands must **never** use Shadow `desired` state — a delayed execution after reconnect is a security risk. Shadow may be revisited later for non-security config (IR LED mode, detection sensitivity, etc.).

### Goal: Use IoT Device Shadow to maintain last-known device state

### What is a Device Shadow?
```
Think of it as a JSON document stored in the cloud that represents
your device's current state. Even when the device is offline, the
cloud (and app) can read the last known state.

Shadow Document:
{
  "state": {
    "reported": { ... },   ← Device tells cloud: "This is my current state"
    "desired": { ... }     ← Cloud/App tells device: "I want you to change to this"
  }
}
```

### Step 6.1 — Update Device Policy for Shadow Access
```bash
# Create updated policy that includes shadow permissions
aws iot create-policy-version \
  --policy-name "vdb-sandbox-policy" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowConnect",
        "Effect": "Allow",
        "Action": "iot:Connect",
        "Resource": "arn:aws:iot:*:*:client/vdb-*"
      },
      {
        "Sid": "AllowDevicePublish",
        "Effect": "Allow",
        "Action": "iot:Publish",
        "Resource": [
          "arn:aws:iot:*:*:topic/vdb/sandbox_001/*/evt",
          "arn:aws:iot:*:*:topic/vdb/sandbox_001/*/telemetry",
          "arn:aws:iot:*:*:topic/vdb/sandbox_001/*/status",
          "arn:aws:iot:*:*:topic/$aws/things/*/shadow/*"
        ]
      },
      {
        "Sid": "AllowDeviceSubscribe",
        "Effect": "Allow",
        "Action": "iot:Subscribe",
        "Resource": [
          "arn:aws:iot:*:*:topicfilter/vdb/sandbox_001/*/cmd",
          "arn:aws:iot:*:*:topicfilter/vdb/system/broadcast",
          "arn:aws:iot:*:*:topicfilter/$aws/things/*/shadow/*"
        ]
      },
      {
        "Sid": "AllowDeviceReceive",
        "Effect": "Allow",
        "Action": "iot:Receive",
        "Resource": [
          "arn:aws:iot:*:*:topic/vdb/sandbox_001/*/cmd",
          "arn:aws:iot:*:*:topic/vdb/system/broadcast",
          "arn:aws:iot:*:*:topic/$aws/things/*/shadow/*"
        ]
      }
    ]
  }' \
  --set-as-default
```

### Step 6.2 — Set Initial Shadow State
```bash
aws iot-data update-thing-shadow \
  --thing-name "vdb-sandbox-001" \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "state": {
      "reported": {
        "connection": "offline",
        "mode": "idle",
        "firmware_version": "1.0.0",
        "surveillance_enabled": false,
        "lock_connected": false,
        "battery_level": 100,
        "face_db_count": 0
      }
    }
  }' \
  /tmp/shadow-output.json

cat /tmp/shadow-output.json | python3 -m json.tool
```

### Step 6.3 — How Shadow Maps to Your Status Topic
```
Your MQTT Schema                    AWS Device Shadow
────────────────                    ─────────────────
vdb/.../status (retain=true)   →    Shadow "reported" state
  connection.status             →    reported.connection
  operational.mode              →    reported.mode
  operational.features          →    reported.surveillance_enabled, etc.
  lock.state                    →    reported.lock_state
  lock.battery_level            →    reported.lock_battery

App sends command               →    Shadow "desired" state
  surveillance.enable           →    desired.surveillance_enabled = true
  stream.start                  →    (use MQTT cmd topic, not shadow)
```

**Rule of thumb**: Use Shadow for **persistent state** (mode, config). Use MQTT topics for **actions** (unlock, stream).

---

## Phase 7: Simulated Device (Python Script)  ✅ COMPLETED

### Goal: Create a Python script that simulates your VDB device connecting to AWS IoT Core

**Status:** Simulator created, connected to IoT Core, full pipeline verified end-to-end.

**Simulator file:** `/home/rayquaza/Documents/mqtt_system_design/vdb_simulator.py`

### Step 7.1 — Install AWS IoT Device SDK ✅
```bash
pip3 install awsiotsdk   # awscrt-0.31.3, awsiotsdk-1.28.2 installed
```

### Step 7.2 — Simulator Script ✅

**File:** `/home/rayquaza/Documents/mqtt_system_design/vdb_simulator.py`

Key behaviours implemented:
- Connects to IoT Core via MTLS (port 8883) using `vdb-sandbox-001` certs
- LWT (Last Will and Testament) configured on the status topic
- Publishes `online` status on connect
- Subscribes to `vdb/sandbox_001/vdb-sandbox-001/cmd`
- Sends telemetry every 30 seconds
- Publishes a doorbell `visitor.button_press` event on Enter key press
- Publishes `offline` status before clean disconnect

**Run modes:**
```bash
# Normal mode — telemetry every 30s, press Enter for doorbell
python3 vdb_simulator.py

# One-shot — publish status + doorbell event then disconnect
python3 vdb_simulator.py --event

# Connection test — connect, publish online, disconnect after 3s
python3 vdb_simulator.py --disconnect
```

**Cert paths used:**
```
cert : /home/rayquaza/Downloads/iotcore_certs/vdb-sandbox-001.cert.pem
key  : /home/rayquaza/Downloads/iotcore_certs/vdb-sandbox-001.private.key
ca   : /home/rayquaza/Downloads/iotcore_certs/AmazonRootCA1.pem
```

### Step 7.3 — Full Pipeline Verification ✅

Pipeline verified: **Simulator → MQTT → IoT Rule → Lambda → DynamoDB**

- `vdb_evt_rule` (SQL: `SELECT *, topic() AS topic FROM 'vdb/+/+/evt'`) → `vdb-event-processor`
- `vdb_status_rule` (SQL: `SELECT *, topic() AS topic FROM 'vdb/+/+/status'`) → `vdb-event-processor`
- DynamoDB `vdb-events` shows `event_type = visitor.button_press` ✅
- DynamoDB `vdb-device-status` shows `status = online` ✅

**Critical note on IoT Rule payload flattening:**
IoT Rule `SELECT *` merges all MQTT payload fields directly into the Lambda `event` dict.
`event['msg_type']` is at the TOP LEVEL — not nested under `event['payload']['msg_type']`.
The nested `payload` object from the MQTT message is accessible as `event['payload']` (stored as `extra` in DynamoDB).

---

## Phase 8: Connect Real Realtek Ameba Pro Board  ⏳ PENDING

### Goal: Port the MQTT client to your actual VDB hardware

### Step 8.1 — Realtek Ameba Pro MQTT Setup Overview
```
The Ameba Pro SDK has a built-in MQTT library (based on Paho).
You need to:
1. Copy certificates to the board (or embed in firmware)
2. Configure WiFi credentials
3. Use the MQTT library with TLS
4. Implement the same message handler pattern
```

### Step 8.2 — Certificate Handling
```c
// Embed certificates in firmware (recommended for production)
// File: certs.h

const char* aws_root_ca = \
"-----BEGIN CERTIFICATE-----\n"
"MIIDQTCCAimgAwIBAgITBmyfz5m...\n"
// ... paste content of AmazonRootCA1.pem
"-----END CERTIFICATE-----\n";

const char* device_cert = \
"-----BEGIN CERTIFICATE-----\n"
// ... paste content of vdb-sandbox-001.cert.pem
"-----END CERTIFICATE-----\n";

const char* device_private_key = \
"-----BEGIN RSA PRIVATE KEY-----\n"
// ... paste content of vdb-sandbox-001.private.key
"-----END RSA PRIVATE KEY-----\n";
```

### Step 8.3 — Ameba Pro MQTT Connection (Pseudo-code)
```c
// This is a simplified version - adapt to your Ameba Pro SDK
#include "MQTTClient.h"
#include "certs.h"

#define MQTT_ENDPOINT    "xxxxx-ats.iot.ap-south-1.amazonaws.com"
#define MQTT_PORT        8883
#define CLIENT_ID        "vdb-sandbox-001"
#define TENANT_ID        "sandbox_001"
#define DEVICE_ID        "vdb-sandbox-001"

#define TOPIC_CMD        "vdb/" TENANT_ID "/" DEVICE_ID "/cmd"
#define TOPIC_EVT        "vdb/" TENANT_ID "/" DEVICE_ID "/evt"
#define TOPIC_TELEMETRY  "vdb/" TENANT_ID "/" DEVICE_ID "/telemetry"
#define TOPIC_STATUS     "vdb/" TENANT_ID "/" DEVICE_ID "/status"

void mqtt_message_callback(MessageData* data) {
    // Parse JSON payload
    cJSON* msg = cJSON_Parse(data->message->payload);
    const char* msg_type = cJSON_GetObjectItem(msg, "msg_type")->valuestring;

    if (strcmp(msg_type, "lock.unlock") == 0) {
        ble_send_unlock();  // Your BLE unlock function
        publish_event("lock.unlocked", ...);
    }
    // ... handle other msg_types
    cJSON_Delete(msg);
}

void mqtt_init() {
    // Configure TLS with certificates
    MQTTClient_connectOptions opts = MQTTClient_connectOptions_initializer;
    opts.ssl_ca_cert = aws_root_ca;
    opts.ssl_client_cert = device_cert;
    opts.ssl_client_key = device_private_key;
    opts.keepAliveInterval = 30;
    opts.clientID = CLIENT_ID;

    // Connect
    MQTTClient_connect(client, MQTT_ENDPOINT, MQTT_PORT, &opts);

    // Subscribe to commands
    MQTTClient_subscribe(client, TOPIC_CMD, QOS1, mqtt_message_callback);

    // Publish online status
    publish_status("online");
}
```

> **Note**: The exact API depends on your Ameba Pro SDK version. The pattern is the same as the Python simulator — just in C.

---

## Phase 9: App Integration (WebSocket MQTT)  ⏳ PENDING

### Goal: Connect the mobile app to AWS IoT Core via MQTT over WebSocket

### Step 9.1 — Why WebSocket?
```
Devices connect via:  MQTT over TLS (port 8883) — using X.509 certificates
Apps connect via:     MQTT over WebSocket (port 443) — using Cognito/IAM tokens

Why? Mobile apps can't easily store X.509 certs. Instead, they authenticate
via Cognito (user login) and get temporary IAM credentials for MQTT.
```

### Step 9.2 — Set Up Cognito for App Auth
```bash
# Create Cognito User Pool (for user login)
aws cognito-idp create-user-pool \
  --pool-name "vdb-users" \
  --auto-verified-attributes email \
  --username-attributes email \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": false
    }
  }'

# Save the User Pool ID from output!

# Create User Pool Client (for app)
aws cognito-idp create-user-pool-client \
  --user-pool-id "YOUR_USER_POOL_ID" \
  --client-name "vdb-mobile-app" \
  --no-generate-secret \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH

# Create Cognito Identity Pool (maps user to IAM role for IoT)
aws cognito-identity create-identity-pool \
  --identity-pool-name "vdb_identity_pool" \
  --allow-unauthenticated-identities false \
  --cognito-identity-providers '[{
    "ProviderName": "cognito-idp.YOUR_REGION.amazonaws.com/YOUR_USER_POOL_ID",
    "ClientId": "YOUR_CLIENT_ID"
  }]'
```

### Step 9.3 — Create IAM Role for Cognito-Authenticated Users
```bash
# Create authenticated role
aws iam create-role \
  --role-name "vdb-cognito-authenticated" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "cognito-identity.amazonaws.com"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "cognito-identity.amazonaws.com:aud": "YOUR_IDENTITY_POOL_ID"
          },
          "ForAnyValue:StringLike": {
            "cognito-identity.amazonaws.com:amr": "authenticated"
          }
        }
      }
    ]
  }'

# Attach IoT permissions
aws iam put-role-policy \
  --role-name "vdb-cognito-authenticated" \
  --policy-name "vdb-iot-access" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "iot:Connect",
          "iot:Subscribe",
          "iot:Receive",
          "iot:Publish"
        ],
        "Resource": "*"
      }
    ]
  }'
```

> **Note**: In production, restrict the Resource ARNs per tenant. The `*` is for sandbox testing only.

### Step 9.4 — React Native / Flutter App MQTT Code (Conceptual)
```javascript
// React Native example using aws-iot-device-sdk-v2
import { mqtt, iot, auth } from 'aws-iot-device-sdk-v2';
import { CognitoIdentityClient } from '@aws-sdk/client-cognito-identity';

const ENDPOINT = 'xxxxx-ats.iot.ap-south-1.amazonaws.com';
const TENANT_ID = 'sandbox_001';

async function connectToIoT(userId, deviceId) {
  // Get Cognito credentials
  const credentials = await getCognitoCredentials();

  // Connect via WebSocket with SigV4 auth
  const connection = new mqtt.MqttClientConnection({
    hostName: ENDPOINT,
    port: 443,
    useWebSocket: true,
    credentials: credentials,
    clientId: `app-${userId}-${Date.now()}`
  });

  await connection.connect();

  // Subscribe to device messages (your wildcard pattern!)
  await connection.subscribe(
    `vdb/${TENANT_ID}/${deviceId}/#`,
    mqtt.QoS.AtLeastOnce,
    (topic, payload) => {
      const msg = JSON.parse(payload);
      handleDeviceMessage(topic, msg);
    }
  );

  // Subscribe to user notifications
  await connection.subscribe(
    `vdb/${TENANT_ID}/user/${userId}/notify`,
    mqtt.QoS.AtLeastOnce,
    (topic, payload) => {
      const msg = JSON.parse(payload);
      handleNotification(msg);
    }
  );

  return connection;
}

function handleDeviceMessage(topic, msg) {
  const msgType = msg.msg_type;
  switch (msgType) {
    case 'visitor.button_press':
      showDoorbell(msg);
      break;
    case 'visitor.face_match':
      showAutoUnlock(msg);
      break;
    case 'lock.unlocked':
      updateLockUI('unlocked');
      break;
    // ... etc
  }
}

// Send unlock command
async function unlockDoor(connection, deviceId, userId) {
  const cmd = {
    msg_type: 'lock.unlock',
    msg_id: generateUUID(),
    timestamp: Date.now(),
    user_id: userId,
    source: 'app',
    payload: {
      reason: 'manual',
      timeout_ms: 5000
    }
  };

  await connection.publish(
    `vdb/${TENANT_ID}/${deviceId}/cmd`,
    JSON.stringify(cmd),
    mqtt.QoS.AtLeastOnce
  );
}
```

---

## Phase 10: Monitoring, Alerts & Production Hardening  ⏳ PENDING

### Goal: Set up CloudWatch monitoring and operational alerts

### Step 10.1 — Enable IoT Core Logging
```bash
# Create logging role
aws iam create-role \
  --role-name "vdb-iot-logging-role" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "iot.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam attach-role-policy \
  --role-name "vdb-iot-logging-role" \
  --policy-arn "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Enable IoT Core logging
aws iot set-v2-logging-options \
  --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/vdb-iot-logging-role" \
  --default-log-level "INFO"
```

### Step 10.2 — Key Metrics to Monitor
```
AWS IoT Core provides these built-in CloudWatch metrics:

Connect:
  - aws/iot/Connect.Success          ← devices connecting
  - aws/iot/Connect.AuthError        ← failed auth (wrong cert/policy)

Messages:
  - aws/iot/PublishIn.Success        ← messages FROM devices
  - aws/iot/PublishOut.Success       ← messages TO devices
  - aws/iot/PublishIn.Throttle       ← rate limiting hit!

Rules:
  - aws/iot/RulesExecuted           ← rules engine processing
  - aws/iot/TopicMatch              ← messages matching topic rules

Shadow:
  - aws/iot/UpdateThingShadow.*     ← shadow updates
```

### Step 10.3 — Create CloudWatch Alarm (Example)
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "vdb-auth-failures" \
  --alarm-description "Alert if devices fail to authenticate" \
  --namespace "AWS/IoT" \
  --metric-name "Connect.AuthError" \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --treat-missing-data notBreaching
```

---

## Cost Estimate (Sandbox / Dev)

```
AWS IoT Core Free Tier (12 months):
  - 500,000 messages/month          ← Plenty for testing
  - 225,000 connection minutes      ← ~5 devices connected 24/7
  - 250,000 shadow ops              ← Plenty
  - 250,000 rule triggers           ← Plenty

Your sandbox usage estimate:
  - 1 simulated device + 1 real device + 1 app ~ 3 connections
  - ~1000 messages/day testing = ~30K/month
  - Cost: $0.00 (well within free tier) ✅

DynamoDB Free Tier:
  - 25 GB storage
  - 25 RCU + 25 WCU (or 200M requests with on-demand)
  - Cost: $0.00 for sandbox ✅

Lambda Free Tier:
  - 1M requests/month
  - 400,000 GB-seconds compute
  - Cost: $0.00 for sandbox ✅

Total sandbox cost: ~$0/month ✅
```

---

## Execution Order (What to Do First)

### Week 1: Foundation
```
✅ Phase 1: AWS account setup, verify IoT Core access
✅ Phase 2: Create Thing, certificates, basic policy
✅ Phase 3: Test with MQTT Test Client in console
```

### Week 2: Intelligence
```
✅ Phase 4: Create proper IoT policies for device/app/cloud
✅ Phase 5: Set up Rules Engine → DynamoDB
      Step 5.8 ✅: vdb-lifecycle-handler Lambda (offline detection)
      Step 5.9 ✅: vdb_lifecycle_rule IoT Rule
⏸ Phase 6: Device Shadow — DEFERRED (not needed for POC)
```

### Week 3: Simulation
```
✅ Phase 7: Python simulator + full pipeline verified
      - connect/disconnect → DynamoDB online/offline ✅
      - doorbell event → DynamoDB vdb-events ✅
      - IoT Rule payload flattening bug found + fixed ✅
```

### Week 4: Real Hardware  ⏳ NEXT
```
⏳ Phase 8: Connect Realtek AMB82 Mini board
⏳ Phase 9: App Integration (API Gateway + Flutter MQTT)
```

### Week 5: Production
```
⏳ Phase 10: Monitoring, alerts, production hardening
```

---

## Quick Reference: Your Topic Mapping on AWS IoT Core

```
Your Schema Topic                         AWS IoT Core Topic           Notes
──────────────────                        ──────────────────           ─────
vdb/{tenant}/{device}/cmd                 Same! ✅                     Commands to device
vdb/{tenant}/{device}/evt                 Same! ✅                     Events from device
vdb/{tenant}/{device}/telemetry           Same! ✅                     Metrics from device
vdb/{tenant}/{device}/status              Same! ✅                     Device state (retained)
vdb/{tenant}/user/{user}/notify           Same! ✅                     Push notifications
vdb/system/broadcast                      Same! ✅                     System-wide messages

Device state persistence                  Device Shadow                $aws/things/{name}/shadow/*
Last Will & Testament                     Built into CONNECT packet    Automatic offline detection
ACL Rules                                 IoT Policies (JSON)          Per-certificate or per-group
Message routing                           Rules Engine                 SQL-like query on topics
```

**Your MQTT schema works directly on AWS IoT Core without modification!**

---

## Troubleshooting Cheat Sheet

| Problem | Cause | Fix |
|---------|-------|-----|
| "Connection refused" | Wrong endpoint URL | Run `aws iot describe-endpoint --endpoint-type iot:Data-ATS` |
| "Not authorized" | Policy doesn't match topic | Check IoT Policy Resource ARNs match your topics |
| "Subscribe failed" | Missing `iot:Subscribe` + `iot:Receive` | Add BOTH actions to policy |
| "Publish failed" | Missing `iot:Publish` | Check policy covers the exact topic path |
| Device disconnects randomly | Keep-alive timeout | Set `keep_alive_secs=30`, ensure network is stable |
| Messages not in DynamoDB | Rule SQL doesn't match | Check rule SQL topic filter matches published topic |
| Shadow not updating | Missing shadow permissions | Add `$aws/things/*/shadow/*` to policy |
| Certificate error | Wrong CA or expired cert | Download fresh AmazonRootCA1.pem |

---



v2 policy is not given to the hardware dev or app dev since they are working with the sandbox001.now since cognito is mentioned the app id is also will be provided by the cognito right which is mapped to the device id of vdb so they can only communicate to each other but the user can have multiple vdb and properties so take care of that .the onboarding app flow is like user first registers the mobile number and verifies the otp so now its registered next user is asked to create a property and name it (here the name will be taken and app will get a tenant id which will be mapped to the name entered by user ,now somehow i have to make sure the property id is unique and identifieble since it is used in the mqtt topic ) .also till then the app ask user to give a name to vdb device and then the page of wifi credentials appear where credentials are put and then through ble vdb is paired and onboarded and through ble these credentials and tenant id and all relevant info is sent to vdb(i have not prepare what all will be the relevant info you can suggest )then vdb connects to cloud and comes online and onboarded .am i missing anything ? .
the next things is fcm token .how will it be taken from app ,does it change for a single device ?how do we take it and map to mqtt since if some events happen then notif is to be sent so only those vdb notif will be sent to app based on the fcm token so that part of architecture needs to be explored and how many db need to created more to continue this project what all will be mapped and how ,i.e. the structure and type of database 



