# Documentation
# this thing will work automagically without problems
# if you have sdkmanager command available in your PATH.
# (you can install sdkmanager using pip or pipx, it's python package)

# if you dont have sdkmanager or if you want to test things,
# to use this script, you need to create appropriate environment.
# install your sdk/ndk and other things you use in your app.
# Then look at my example, here's what I'll put in .bashrc or somewhere
# I wish (important ones go first, other ones are automatic most of the time):
# export ANDROID_HOME=$HOME/Android/Sdk
# export ANDROID_NDK_VERSION="26.2.11394342"
# export ANDROID_BUILDTOOLS_VERSION="34.0.0"
# export ANDROID_LEGACY_PLATFORM=21
# export ANDROID_TARGET_PLATFORM=34
# export ANDROID_DEVELOPER_PLATFORM="linux-x86_64"

# (End Of Documentation)

# here I set defaults for those variables

export ANDROID_HOME=${ANDROID_HOME:-"$HOME/Android/Sdk"}
export ANDROID_NDK_VERSION=${ANDROID_NDK_VERSION:-"26.2.11394342"}
export ANDROID_BUILDTOOLS_VERSION=${ANDROID_BUILDTOOLS_VERSION:-"34.0.0"}
export ANDROID_LEGACY_PLATFORM=${ANDROID_LEGACY_PLATFORM:-"21"}
export ANDROID_TARGET_PLATFORM=${ANDROID_TARGET_PLATFORM:-"34"}
export ANDROID_DEVELOPER_PLATFORM=${ANDROID_DEVELOPER_PLATFORM:-"linux-x86_64"}
export KEY_STORE=${KEY_STORE:-"debug.keystore"} # key store with "release" key
export KS_PASS=${KS_PASS:-"pass:mypassword"} # password for the key store
export KEY_PASS=${KEY_PASS:-"pass:mypassword"} # password for the key key


# and generate other variables based on defined ones

export ANDROID_SDK_ROOT=$ANDROID_HOME
export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/$ANDROID_NDK_VERSION"
export PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$ANDROID_DEVELOPER_PLATFORM/bin:$PATH"
export PATH="$ANDROID_SDK_ROOT/build-tools/$ANDROID_BUILDTOOLS_VERSION:$PATH"

# start of build process

# first, try to install missing sdk components
if command -v sdkmanager &> /dev/null
then
    mkdir -p "${ANDROID_HOME}"
    yes | sdkmanager --sdk_root=${ANDROID_HOME} --licenses
    sdkmanager --sdk_root=${ANDROID_HOME} "build-tools;${ANDROID_BUILDTOOLS_VERSION}" "cmake;3.22.1" "ndk;${ANDROID_NDK_VERSION}" "platform-tools" "platforms;android-${ANDROID_TARGET_PLATFORM}" "tools"
else
    echo "sdkmanager command not found; continuing with hope you read the docs"
fi

for arch in x86 x86_64 armeabi armeabi-v7a arm64-v8a; do
    xmake f --ndk_sdkver=$ANDROID_LEGACY_PLATFORM -vDy -p android -m release -a $arch && xmake build -vDy native-activity
    mkdir -p build/apk/lib/$arch
    cp -f build/android/$arch/**/*.so build/apk/lib/$arch
    export ARCH=$arch


# this magic copies .so files from all add_require() dependencies.
# ... Probably from all dependencies.

xrepo env bash <<'EOF'
        # Set the output directory
        OUT="build/apk/lib/$ARCH"

        # Split the LIBRARY_PATH into an array using ":" as the delimiter
        IFS=":" read -ra PATHS <<< "$LIBRARY_PATH"

        # Iterate over each path in the PATHS array
        for path in "${PATHS[@]}"; do
        # Check if the path exists and is a directory
        if [ -d "$path" ]; then
            # Copy all .so files from the path to the output directory
            cp "$path"/*.so "$OUT"
            echo "Copied .so files from $path to $OUT"
        else
            echo "Path $path does not exist or is not a directory"
        fi
        done
EOF
done

# usual android packaging stuff

aapt package -f -M AndroidManifest.xml -I $ANDROID_SDK_ROOT/platforms/android-$ANDROID_TARGET_PLATFORM/android.jar -S res -F apk-unaligned.apk build/apk

zipalign -f 4 apk-unaligned.apk apk-unsigned.apk



# generate and use keys on the fly (because I don't want build script to ask for password

rm debug.keystore
keytool -genkey -v -keystore debug.keystore -alias debug -keyalg RSA -keysize 2048 -validity 10000 -storepass mypassword -keypass mypassword -dname "CN=John Doe, OU=Mobile Development, O=My Company, L=New York, ST=NY, C=US" -noprompt


# you can use your "release" keys if wanted by overriding $KEY_STORE variable in your .bashrc for example

apksigner sign --ks $KEY_STORE --ks-pass $KS_PASS --key-pass $KEY_PASS --out app.apk apk-unsigned.apk

rm apk-unsigned.apk apk-unaligned.apk app.apk.idsig debug.keystore
rm -rf build .xmake
