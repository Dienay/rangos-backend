#!/bin/bash

# Execution script for Docker Compose projects

set -e

# Função para mostrar ajuda
show_help() {
  echo "Execution script for Docker Compose projects"
    echo ""
    echo "Uso: ./run.sh <comando>"
    echo ""
    echo "Comandos disponíveis:"
    echo "  up    - Inicia os containers"
    echo "  build - Build dos containers"
    echo "  rebuild - Rebuild dos containers"
    echo "  rebuild:force - Rebuild com force-recreate"
    echo "  down  - Para e remove os containers"
    echo "  logs  - Mostra logs em tempo real"
    echo "  stop  - Para os containers"
    echo "  restart - Reinicia os containers"
    echo "  ps    - Lista containers em execução"
}

# Verifica se um comando foi fornecido
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

COMMAND=$1
shift

# Função para executar comandos docker-compose
function docker-compose() {
    docker compose "$@"
}

# Comandos disponíveis
case $COMMAND in
    up)
        docker-compose up
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
esac
