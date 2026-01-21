#!/bin/bash
DIR=`pwd`
RELEASE="go1.25.6.linux-amd64.tar.gz"
ARCHIVE="$DIR/$RELEASE"
if [ ! -f $ARCHIVE ];
then
	wget https://go.dev/dl/$RELEASE
fi
cd /usr/local
if [ ! -d go ]; then
	tar zxvf $ARCHIVE
fi
HAVE_GO_BIN=`grep -c '\$HOME\/go\/bin' $HOME/.bashrc`
if [ $HAVE_GO_BIN -eq 0 ]; then
	if [ -d $HOME/go/bin ]; then
		echo "Warning: You have a user-specific Go bin folder, but it isn't in your path yet."
	fi
fi
HAVE_GO=`grep -c 'usr\/local\/go\/bin' $HOME/.bashrc`
if [ $HAVE_GO -eq 1 ];
then
	HAVE_GO_TEST=`go 2>&1 |grep -c "Go is a tool for managing Go source code"`
	if [ $HAVE_GO_TEST -eq 1 ];
	then
		echo "Go ready for use."
	else
		echo "You probably need to add /usr/local/go/bin to your PATH"
	fi
else
	echo "You need to patch \$HOME/.bashrc to include the line below"
	echo
	echo "export PATH=\"\$PATH:/usr/local/go/bin:\$HOME/go/bin\""
fi
