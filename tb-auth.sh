echo 'ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"' | sudo tee /etc/udev/rules.d/99-thunderbolt-auto.rules

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=thunderbolt
