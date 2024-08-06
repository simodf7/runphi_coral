# Use Alpine Linux as the base image
FROM scratch

# Copy the binary into the /boot directory inside the container
COPY zephyr.bin /boot/hello.bin
COPY arch.txt /boot/arch.txt
COPY config.json /boot/
# Optionally, you may want to perform additional actions or configurations here

# Set any required environment variables or expose any necessary ports

# Cleanup unnecessary packages and files to minimize the image size
LABEL org.opencontainers.image.os.features="jailhouse"
# Set the working directory
WORKDIR /boot

# Command to run when the container starts
CMD ["sh"]

