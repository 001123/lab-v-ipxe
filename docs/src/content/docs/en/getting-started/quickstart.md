---
title: Quickstart
description: Setting up your development environment and running iPXE ZTP locally.
---

This guide gets your local development environment up and running in a few simple steps.

## Prerequisites

Before starting, ensure you have the following installed on your machine:

- **[mise](https://mise.jdx.dev/)** (recommended tool manager) or:
  - **V** compiler (`0.5.2` or later)
  - **Node.js** (v20+ or v22 LTS) and **npm**
  - **SQLite 3**
  - **curl** and **lsof**

## 1. Clone the Repository

```bash
git clone https://github.com/001123/lab-v-ipxe.git
cd lab-v-ipxe
```

If using `mise`, trust the configuration once:

```bash
mise trust
```

## 2. Install Frontend Dependencies

```bash
cd web && npm install && cd ..
```

## 3. Run Development Stack

Start both the V backend and Next.js frontend dev servers simultaneously using `mise`:

```bash
mise run dev
```

The task will:
1. Automatically terminate any dangling processes from previous runs on ports `:4793` and `:4794`.
2. Start the V backend server on `http://localhost:4793`.
3. Wait for the backend `/healthz` check to pass.
4. Launch the Next.js dev server on `http://localhost:4794` with API proxying.

## 4. Access the Web Console

Open your web browser and navigate to:

- **URL**: [http://localhost:4794](http://localhost:4794)
- **Email**: `admin@ipxe.local`
- **Password**: `admin@pwd`

## 5. Building the Single Production Binary

To build a self-contained, standalone production binary with the frontend web interface embedded:

```bash
# 1. Export the Next.js static assets
cd web && npm run build && cd ..

# 2. Generate the V static asset embedding source file
v run scripts/gen_embed.vsh

# 3. Compile the production binary
v -prod -o bin/lab-v-ipxe .
```

Now you can execute the single binary anywhere:

```bash
./bin/lab-v-ipxe
```

By default, the production binary serves both the web UI and APIs on port `4793`.

## 6. Running the Documentation Server

To run this documentation site locally:

```bash
mise run docs:dev
```

Visit [http://localhost:4795](http://localhost:4795) to view the documentation.
