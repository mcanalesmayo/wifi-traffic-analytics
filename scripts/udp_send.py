import socket
import threading
import struct

REMOTE_IP = "155.210.155.137"
REMOTE_PORT = 8080

N_PACKETS = 100000

fd = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

seq = 0
def udp_send():
    threading.Timer(0.01, udp_send).start()
    global seq
    seq += 1
    n_bytes = fd.sendto(bytes(struct.pack('!Q', seq)), (REMOTE_IP, REMOTE_PORT))
    print("%d bytes sent\n" % (n_bytes,))

udp_send()