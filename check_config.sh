#!/bin/bash

GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"
TICK="${GREEN}✔${RESET}"
CROSS="${RED}✗${RESET}"

print_header() {
  echo "==============================================="
  printf "         %s\n" "$1"
  echo "==============================================="
}

normalize_address() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

check_logs() {
  print_header "1. Docker Logs — Адреса ноды"
  local container_id=$(docker ps -q --filter name=aztec | head -n 1)
  if [[ -z "$container_id" ]]; then
    echo -e "${CROSS} Контейнер aztec не найден"
    return
  fi

  echo -e "${TICK} Контейнер найден: $container_id"
  local logs=$(docker logs "$container_id" 2>&1)

  local validators=()
  local sequencer=""

  while IFS= read -r line; do
    if [[ "$line" == *"validator"* && "$line" == *"address"* ]]; then
      addr=$(echo "$line" | grep -oE '0x[a-fA-F0-9]{40}')
      if [[ -n "$addr" ]]; then
        validators+=("$(normalize_address "$addr")")
      fi
    fi
    if [[ "$line" == *"sequencer"* && "$line" == *"address"* ]]; then
      sequencer=$(echo "$line" | grep -oE '0x[a-fA-F0-9]{40}')
    fi
  done <<< "$logs"

  echo -e "${TICK} Найдено валидаторов: ${#validators[@]}"
  for v in "${validators[@]}"; do
    echo "   - $v"
  done

  if [[ -n "$sequencer" ]]; then
    echo -e "${TICK} Sequencer: $(normalize_address "$sequencer")"
  else
    echo -e "${CROSS} Адрес sequencer не найден"
  fi
}

check_yml_env_presence() {
  print_header "2. Наличие файлов конфигурации"

  local base_dir="/root/aztec"
  local yml="$base_dir/docker-compose.yml"
  local env="$base_dir/.env"

  if [[ -f "$yml" ]]; then
    echo -e "${TICK} docker-compose.yml найден"
  else
    echo -e "${CROSS} docker-compose.yml не найден"
  fi

  if [[ -f "$env" ]]; then
    echo -e "${TICK} .env найден"
  else
    echo -e "${CROSS} .env не найден"
  fi
}

check_env_required_keys() {
  print_header "3. Проверка обязательных переменных в .env"

  local env_file="/root/aztec/.env"
  local required_keys=(
    "ETHEREUM_RPC_URL"
    "CONSENSUS_BEACON_URL"
    "VALIDATOR_PRIVATE_KEYS"
    "COINBASE"
    "P2P_IP"
  )

  if [[ ! -f "$env_file" ]]; then
    echo -e "${CROSS} Файл .env не найден"
    return
  fi

  local all_ok=1

  for key in "${required_keys[@]}"; do
    val=$(grep -m1 "^$key=" "$env_file" | cut -d '=' -f2- | xargs)
    if [[ -z "$val" ]]; then
      echo -e "${CROSS} $key отсутствует или пуст"
      all_ok=0
    else
      echo -e "${TICK} $key = $val"
    fi
  done

  if [[ $all_ok -eq 1 ]]; then
    echo -e "${GREEN}✔ Все ключи присутствуют и заполнены${RESET}"
  else
    echo -e "${RED}✗ Есть недостающие или пустые переменные${RESET}"
  fi
}

# ========== Главная точка входа ==========

main() {
  check_logs
  check_yml_env_presence
  check_env_required_keys
}

main
