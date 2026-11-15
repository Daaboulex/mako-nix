#include "mako_fg_protocol.hpp"

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <spawn.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>

extern char** environ;

using namespace mako::backend::fg_host;

namespace {
bool exchange(const int socket, const Request& request, Reply& reply) {
    if (send(socket, &request, sizeof request, MSG_NOSIGNAL) != ssize_t(sizeof request))
        return false;
    ssize_t received;
    do
        received = recv(socket, &reply, sizeof reply, 0);
    while (received < 0 && errno == EINTR);
    return received >= ssize_t(offsetof(Reply, text));
}
}

int main(int count, char** arguments) {
    if (count != 4) {
        std::fprintf(stderr, "usage: %s LINKER LIBRARY_PATH MAKO_FG_HOST\n", arguments[0]);
        return 2;
    }
    std::array<int, 2> sockets{-1, -1};
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, sockets.data()) != 0) {
        std::perror("socketpair");
        return 1;
    }
    char option[] = "--library-path";
    std::array<char*, 5> command{arguments[1], option, arguments[2], arguments[3], nullptr};
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, sockets[1], hostDescriptor);
    pid_t process{};
    const int spawned = posix_spawn(&process, command[0], &actions, nullptr, command.data(), environ);
    posix_spawn_file_actions_destroy(&actions);
    close(sockets[1]);
    if (spawned != 0) {
        std::fprintf(stderr, "the linker %s could not be started: %s\n", command[0], std::strerror(spawned));
        return 1;
    }
    int status{};
    while (waitpid(process, &status, 0) < 0 && errno == EINTR) {
    }
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        std::fprintf(stderr, "mako-fg-host did not start through %s with the library path %s\n", arguments[1], arguments[2]);
        return 1;
    }
    const timeval limit{60, 0};
    setsockopt(sockets[0], SOL_SOCKET, SO_RCVTIMEO, &limit, sizeof limit);

    Request hello{};
    hello.op = Hello;
    Reply reply{};
    if (!exchange(sockets[0], hello, reply) || reply.failed) {
        std::fprintf(stderr, "mako-fg-host did not answer the Renderer's Hello: %.200s\n", reply.text);
        return 1;
    }
    if (reply.first != hostProtocol || reply.second != sizeof(Request)) {
        std::fprintf(stderr,
            "mako-fg-host speaks protocol %u with %u-byte requests; this Renderer speaks protocol %u with %zu-byte requests, so the pinned MAKO FG release does not fit it\n",
            reply.first, reply.second, hostProtocol, sizeof(Request));
        return 1;
    }
    std::printf("host=%.200s protocol=%u\n", reply.text, reply.first);

    Request devices{};
    devices.op = Devices;
    reply = Reply{};
    if (!exchange(sockets[0], devices, reply) || reply.failed) {
        std::fprintf(stderr, "mako-fg-host could not list Vulkan devices: %.200s\n", reply.text);
        return 1;
    }
    if (reply.first == 0) {
        std::fprintf(stderr, "mako-fg-host found no Vulkan device, so it did not reach a Vulkan loader and driver\n");
        return 1;
    }
    std::array<GpuInfo, 8> gpus{};
    const size_t listed = std::min<size_t>(reply.first, gpus.size());
    std::memcpy(gpus.data(), reply.text, listed * sizeof(GpuInfo));
    for (size_t index = 0; index < listed; index++)
        std::printf("device=%.255s\n", gpus[index].name);
    return 0;
}
