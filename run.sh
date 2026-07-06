#!/bin/bash

# Execution script for Docker Compose projects

set -e

# Displays help text
show_help() {
  echo "Execution script for Docker Compose projects"
  echo ""
  echo "Usage: ./run.sh <command>"
  echo ""
  echo "Available commands:"
  echo "  up [args]     - Start the containers (defaults to --attach api;"
  echo "                  pass your own args to override, e.g."
  echo "                  run up --attach mongo redis)"
    echo "  rebuild:force - Rebuild com force-recreate"
  echo "  build         - Build the containers"
  echo "  rebuild       - Rebuild the containers"
  echo "  rebuild:force - Rebuild with force-recreate"
  echo "  down          - Stop and remove the containers"
  echo "  logs [service] - Show live logs (optionally filtered to one or"
  echo "                  more services, e.g. run logs redis)"
  echo "  stop          - Stop the containers"
  echo "  restart       - Restart the containers"
  echo "  ps            - List running containers"
  echo "  clean         - Remove containers, volumes, local images and"
  echo "                  orphaned/dangling resources from this project"
  echo "  clean:all     - Same as clean, but also removes third-party"
  echo "                  images used by the project (e.g. postgres, redis)"
  echo "  purge         - FULL cleanup of the project: containers, images,"
  echo "                  volumes, networks and build cache related to"
  echo "                  this project, including leftovers that"
  echo "                  compose down doesn't reach"
}

# Requires at least one command
if [ $# -eq 0 ]; then
  show_help
  exit 1
fi

COMMAND=$1
shift

# Wrapper so the rest of the script can keep using the docker-compose name
function docker-compose() {
  docker compose "$@"
}

# Resolves the project name by asking Docker Compose directly, respecting
# its own priority order (-p > COMPOSE_PROJECT_NAME/.env > "name:" in the
# compose file > directory name). This makes the script reusable across any
# project without needing to edit anything here.
resolve_project_name() {
  PROJECT_NAME=$(docker compose config 2>/dev/null | awk '/^name:/{print $2; exit}')

  if [ -z "$PROJECT_NAME" ]; then
    echo "Error: could not determine the project name." >&2
    echo "Run this script from the project folder (where docker-compose.yml is)." >&2
    exit 1
  fi
}

# Removes dangling resources that belong to the project, via label.
# Docker Compose tags everything it creates with
# com.docker.compose.project=<name>, so filtering by that label guarantees
# resources from other projects are never touched.
clean_dangling_by_label() {
  local filter="label=com.docker.compose.project=${PROJECT_NAME}"

  echo ">> Cleaning up orphaned volumes for project '${PROJECT_NAME}'..."
  docker volume prune -f --filter "$filter" || true

  echo ">> Cleaning up dangling images for project '${PROJECT_NAME}'..."
  docker image prune -f --filter "$filter" || true

  echo ">> Cleaning up unused networks for project '${PROJECT_NAME}'..."
  docker network prune -f --filter "$filter" || true
}

# Removes any container/image carrying the project's label, even if it is
# no longer tied to the compose lifecycle (e.g. a manually stopped or
# renamed container, or leftovers from an older version of the compose file).
purge_everything_by_label() {
  local filter="label=com.docker.compose.project=${PROJECT_NAME}"

  echo ">> Removing remaining containers for project '${PROJECT_NAME}'..."
  local containers
  containers=$(docker ps -a -q --filter "$filter")
  if [ -n "$containers" ]; then
    docker rm -f $containers
  fi

  echo ">> Removing ALL images for project '${PROJECT_NAME}' (not just dangling)..."
  local images
  images=$(docker images -q --filter "$filter")
  if [ -n "$images" ]; then
    docker rmi -f $images || true
  fi

  echo ">> Cleaning up build cache for project '${PROJECT_NAME}'..."
  docker builder prune -f --filter "$filter" || true
}

# Available commands
case $COMMAND in
  up)
    if [ $# -eq 0 ]; then
      docker-compose up --attach api
    else
      docker-compose up "$@"
    fi
  ;;
        docker-compose up --build
        ;;
    rebuild:force)
        docker-compose up --build --force-recreate
        ;;
    down)
        docker-compose down
        ;;
    logs)
        docker-compose logs -f
        ;;
    stop)
        docker-compose stop
        ;;
    restart)
        docker-compose restart
        ;;
    ps)
        docker-compose ps
        ;;
    *)
        show_help
        exit 1
        ;;
  build)
    docker-compose build
  ;;
  rebuild)
    docker-compose up --build
  ;;
  rebuild:force)
    docker-compose up --build --force-recreate
  ;;
  down)
    docker-compose down
  ;;
  logs)
    docker-compose logs -f "$@"
  ;;
  stop)
    docker-compose stop
  ;;
  restart)
    docker-compose restart
  ;;
  ps)
    docker-compose ps
  ;;
  clean)
    resolve_project_name
    echo ">> Tearing down containers, volumes and locally built images..."
    # --rmi local only removes images that compose BUILT (e.g. your app),
    # preserving pulled third-party images (postgres, redis, etc).
    docker-compose down -v --remove-orphans --rmi local
    clean_dangling_by_label
    echo ">> Cleanup complete for project '${PROJECT_NAME}'."
  ;;
  clean:all)
    resolve_project_name
    echo ">> Tearing down containers, volumes and ALL images (including third-party)..."
    docker-compose down -v --remove-orphans --rmi all
    clean_dangling_by_label
    echo ">> Full cleanup complete for project '${PROJECT_NAME}'."
  ;;
  purge)
    resolve_project_name
    echo ">> Starting FULL cleanup for project '${PROJECT_NAME}'..."
    echo ">> This will remove containers, images, volumes, networks and"
    echo "   build cache related to this project. This action is irreversible."
    read -p "Confirm? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Cancelled."
      exit 0
    fi

    docker-compose down -v --remove-orphans --rmi all || true
    clean_dangling_by_label
    purge_everything_by_label

    echo ">> Purge complete. Environment cleaned for project '${PROJECT_NAME}'."
  ;;
  *)
      show_help
      exit 1
      ;;
esac
