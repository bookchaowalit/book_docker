# JupyterHub Configuration
import os

# Configuration file for JupyterHub
c = get_config()

# Docker spawner configuration
c.JupyterHub.spawner_class = "dockerspawner.DockerSpawner"
c.DockerSpawner.image = os.environ.get(
    "DOCKER_JUPYTER_CONTAINER", "jupyter/datascience-notebook:latest"
)
c.DockerSpawner.network_name = os.environ.get("DOCKER_NETWORK_NAME", "shared-networks")
c.DockerSpawner.remove = True
c.DockerSpawner.debug = True

# Hub configuration
c.JupyterHub.hub_ip = "0.0.0.0"
c.JupyterHub.hub_port = 8000

# Authentication
c.Authenticator.admin_users = {"admin"}
c.LocalAuthenticator.create_system_users = True

# Networking
c.JupyterHub.ip = "0.0.0.0"
c.JupyterHub.port = 8000
