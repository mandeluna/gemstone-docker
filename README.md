# GemStone/S 64 Bit Docker Environment

A persistent, containerized environment for GemStone/S 64 Bit (v3.7.4.3). This setup includes automated initialization of the extent, correct handling of shared memory, and a configured NetLDI for remote access.

## Notes regarding versioning
* The version should be only listed in one spot in the Dockerfile. Check (GemStone's website)[https://gemtalksystems.com/products/gs64/] for the 
* correct version to use. If the version does not exist the script will fail with an HTTP error (403 probably).

## Features
* **Version:** GemStone/S 64 Bit 3.7.4.3
* **Base Image:** Ubuntu 22.04
* **Persistence:** Automated initialization and mounting of `extent0.dbf`.
* **Networking:** Configured for both host-local (RPC) and container-local (Shared Memory) access.
* **Security:** Runs as the non-root `gemstone` user (using `gosu` for privilege de-escalation).

## Prerequisites
1.  **Docker Desktop** (or Docker Engine + Compose)
2.  **GemStone Key File:** This environment will use the community key from the GS distribution
3.  **GemStone Client:** To connect from your host, you need the `topaz` executable for v3.7.4.3 installed locally.

Note that the "linked" `topaz -l` command will only work from inside the container, and will only run from 
the `gemstone` user account. You may need to set $GEMSTONE and $PATH environment variables for this to work,
as the Dockerfile does not handle this for you. If you use this you will most likely want to connect from an
external Smalltalk image.

## Setup & Installation

### 1. Build the Image
Clone this repository and build the container. The build process automatically downloads the GemStone product zip.

```bash
docker compose build --no-cache

```

### 2. Start the Server

Start the container in detached mode.

```bash
docker compose up -d

```

**First Run Behavior:**

* The container creates a `./gemstone-data` directory on your host.
* It initializes a fresh `extent0.dbf` and `system.conf` if they are missing.
* It starts the Stone (`gs64stone`) and the NetLDI (`gs64ldi`).

### 3. Verify the Status

Check the logs to ensure the Stone started correctly:

```bash
docker compose logs -f

```

*You should see:* `--- Starting Stone: gs64stone ---`

## Connecting to the Database

### Option A: From Inside the Container (Shared Memory)

This is the fastest method and useful for debugging.

1. Enter the container:
```bash
docker exec -it gs64stone bash

```


2. Switch to the `gemstone` user (preserves environment variables):
```bash
su gemstone

```


3. Run Topaz:
```bash
topaz -l

```


4. Login:
```smalltalk
set user SystemUser pass swordfish
login

```



### Option B: From Host Machine (RPC / NetLDI)

To connect from your local laptop/workstation using a local `topaz` client:

1. Ensure you have `libxcrypt-compat` installed on your host (required for modern Linux kernels).
2. Start Topaz:
```bash
# Ensure LD_LIBRARY_PATH includes your GemStone lib directory
export LD_LIBRARY_PATH=$GEMSTONE/lib:$LD_LIBRARY_PATH
topaz

```


3. Login using the **NRS String** (bypasses IPv6 lookup issues):
```smalltalk
set user SystemUser pass swordfish

! Connect via IPv4 loopback to the NetLDI listening on port 50378
set stone !@127.0.0.1!#netldi:gs64ldi!gs64stone

login

```



## Configuration

### Shared Memory

The `docker-compose.yml` configures `shm_size: '2gb'` and sets `ulimits` for `memlock`. If you increase the cache size in `system.conf`, ensure you increase the `shm_size` in the compose file to match.

### Data Persistence

All database files are stored in the `./gemstone-data` directory on your host.

* **extent0.dbf:** The object database.
* **system.conf:** The configuration file.
* **tranlog/:** Transaction logs (if enabled).

To reset the database entirely, stop the container and delete the contents of `./gemstone-data`.

## Troubleshooting

* **Error: `NetLDI service not found on node ::1**`
* *Cause:* Topaz is trying to use IPv6.
* *Fix:* Use the NRS string syntax (`!@127.0.0.1...`) in the gemnetid string.


* **Error: `No such file or directory` (logs)**
* *Cause:* Directory permission mismatch.
* *Fix:* Ensure `docker compose build` was run after any changes to `entrypoint.sh`.

