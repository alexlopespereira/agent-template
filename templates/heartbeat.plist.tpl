<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>{{ REPO_OWNER }}.{{ AGENT_NAME }}.heartbeat</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-l</string>
    <string>{{ WORK_DIR }}/heartbeat.sh</string>
  </array>
  <key>StartInterval</key>
  <integer>{{ HEARTBEAT_SECONDS }}</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>WorkingDirectory</key>
  <string>{{ WORK_DIR }}</string>
  <key>StandardOutPath</key>
  <string>{{ WORK_DIR }}/logs/heartbeat.log</string>
  <key>StandardErrorPath</key>
  <string>{{ WORK_DIR }}/logs/heartbeat.err</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>{{ USER_HOME }}</string>
    <key>PATH</key>
    <string>{{ USER_HOME }}/.local/bin:{{ USER_HOME }}/.nvm/versions/node/v22.0.0/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
