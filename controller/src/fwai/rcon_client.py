from __future__ import annotations

import socket
import struct
from dataclasses import dataclass


SERVERDATA_AUTH = 3
SERVERDATA_AUTH_RESPONSE = 2
SERVERDATA_EXECCOMMAND = 2
SERVERDATA_RESPONSE_VALUE = 0


@dataclass(frozen=True)
class RCONPacket:
    request_id: int
    packet_type: int
    body: str


class RCONClient:
    def __init__(self, host: str, port: int, password: str, timeout: float = 10.0) -> None:
        self._host = host
        self._port = port
        self._password = password
        self._timeout = timeout
        self._sock: socket.socket | None = None
        self._next_id = 1

    def connect(self) -> None:
        if self._sock is not None:
            return
        sock = socket.create_connection((self._host, self._port), timeout=self._timeout)
        sock.settimeout(self._timeout)
        self._sock = sock
        self._authenticate()

    def close(self) -> None:
        if self._sock is not None:
            self._sock.close()
            self._sock = None

    def command(self, text: str) -> str:
        self.connect()
        if self._sock is None:
            raise RuntimeError("RCON socket is not available")

        request_id = self._new_id()
        self._send_packet(RCONPacket(request_id, SERVERDATA_EXECCOMMAND, text))

        packet = self._recv_packet()
        if packet.request_id != request_id:
            # Keep reading until we find our matching packet.
            while packet.request_id != request_id:
                packet = self._recv_packet()
        return packet.body

    def _authenticate(self) -> None:
        request_id = self._new_id()
        self._send_packet(RCONPacket(request_id, SERVERDATA_AUTH, self._password))

        packet = self._recv_packet()
        # Some servers send an empty response packet before auth response.
        if packet.packet_type == SERVERDATA_RESPONSE_VALUE:
            packet = self._recv_packet()

        if packet.packet_type != SERVERDATA_AUTH_RESPONSE:
            raise RuntimeError(f"unexpected auth response type: {packet.packet_type}")
        if packet.request_id == -1:
            raise RuntimeError("RCON authentication failed")

    def _new_id(self) -> int:
        current = self._next_id
        self._next_id += 1
        return current

    def _send_packet(self, packet: RCONPacket) -> None:
        if self._sock is None:
            raise RuntimeError("socket is not connected")
        body_bytes = packet.body.encode("utf-8")
        payload = struct.pack("<ii", packet.request_id, packet.packet_type) + body_bytes + b"\x00\x00"
        data = struct.pack("<i", len(payload)) + payload
        self._sock.sendall(data)

    def _recv_packet(self) -> RCONPacket:
        if self._sock is None:
            raise RuntimeError("socket is not connected")
        size_bytes = self._recv_exact(4)
        (size,) = struct.unpack("<i", size_bytes)
        payload = self._recv_exact(size)
        request_id, packet_type = struct.unpack("<ii", payload[:8])
        body = payload[8:-2].decode("utf-8", errors="replace")
        return RCONPacket(request_id=request_id, packet_type=packet_type, body=body)

    def _recv_exact(self, length: int) -> bytes:
        if self._sock is None:
            raise RuntimeError("socket is not connected")
        chunks: list[bytes] = []
        bytes_read = 0
        while bytes_read < length:
            chunk = self._sock.recv(length - bytes_read)
            if not chunk:
                raise RuntimeError("connection closed while receiving RCON packet")
            chunks.append(chunk)
            bytes_read += len(chunk)
        return b"".join(chunks)
