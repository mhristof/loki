module "loki" {
  source = "# TODO change me"

  name = "loki"

  vpc = {
    name        = "TODO: change me"
    subnet_name = "TODO: change me"
  }
  user_data_replace_on_change = false
  enable_docker               = true
  instance_type               = "t3.medium"
  public_ip                   = true

  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "allowDescribe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
        ]
        Resource = "*"
      },
    ]
  })

  ami_name = "al2023-ami-2023.3.*-x86_64"

  user_data = <<-EOF
    wget https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_amd64 -O /usr/local/bin/yq
    chmod +x /usr/local/bin/yq

    cd /root
    wget https://raw.githubusercontent.com/grafana/loki/v3.0.0/cmd/loki/loki-local-config.yaml -O loki-config.yaml

    cat << 'EOP' >> loki-config.yaml
    limits_config:
      max_label_names_per_series: 40
    EOP


    docker rm -f loki || true
    docker run --user root --name loki \
      -d \
      -v $(pwd):/mnt/config \
      -v /data/retention:/data/retention \
      -p 3100:3100 \
      grafana/loki:3.0.0 -config.file=/mnt/config/loki-config.yaml

    if ! promtail -version | grep -q 2.9.8; then
      wget https://github.com/grafana/loki/releases/download/v2.9.8/promtail-linux-amd64.zip
      unzip promtail-linux-amd64.zip
      rm promtail-linux-amd64.zip
      mv promtail-linux-amd64 /usr/local/bin/promtail
    fi

    cat << 'EOP' > /usr/local/bin/metadata
    ${file("metadata.sh")}
    EOP
    chmod +x /usr/local/bin/metadata


    mkdir -p /var/lib/promtail
    /usr/local/bin/metadata > /var/lib/promtail/metadata

    cat <<'EOP' > /etc/promtail-config.yaml
    ${file("promtail.yml")}
    EOP

    cat <<'EOP' > /etc/systemd/system/promtail.service
    [Unit]
    Description=Promtail service
    After=network.target

    [Service]
    EnvironmentFile=/var/lib/promtail/metadata
    ExecStartPre=/usr/local/bin/promtail -config.file=/etc/promtail-config.yaml -check-syntax -config.expand-env=true
    ExecStart=/usr/local/bin/promtail -config.file /etc/promtail-config.yaml -config.expand-env=true
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOP

    systemctl daemon-reload
    systemctl enable promtail
    systemctl start promtail

    docker rm -f test || true
    docker run -d --rm --name test ubuntu bash -c 'while true; do echo "$(date --iso-8601=seconds) mikec"; sleep 1; done'

  EOF
}

