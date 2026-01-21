#!/bin/bash
go install github.com/mark3labs/mcphost@latest
cd /source
if [ ! -d phext-mcp ]; then
	git clone git@github.com:wbic16/phext-mcp.git
fi
cd /source/phext-mcp
cargo build --release
if [ ! -f ~/.mcphost.yml ];
then
	cp mcphost-config.yml
	echo "Installed default mcphost config"
else
	echo "Review mcphost-config.yml"
fi
$HOME/go/bin/mcphost -m ollama:llama4:scout
