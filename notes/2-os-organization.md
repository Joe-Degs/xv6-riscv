## Operating System Organization

OSs are organized to fulfil these three requirements;
1. __multiplex__ multiple processes (apps) over hardware
2. __isolate__ the process from each other
3. __facilitate__ interactions between isolated processes

### abstracting physical resources (__multiplex__)
you have to big or small electrical device right? you need to use it to learn,
watch movies, play games. How is it possible to use the electrical device for
all this things.

The OS is the abstraction on top of the physical device that makes it possible
to use the hardware for specific things that satisfy the user. The OS provides
simple interfaces called `syscall` which are ways to interact with the hardware
without having any hardware specific knowledge.

And so if you call the `read` *syscall* to read the contents of a file on the
disk. You don't have to know the physics of the disk to do this. The OS takes of
that for you, it knows how disks work and it knows how to interact with it.

If you have a computer, chances are you are running multiple apps at the same
time and it all seems to be working seamlessly and simultaneously. But are these
apps really running simultaneously on the hardware? Probably not.
Most modern OSs are *time sharing* systems, they multiplex the many apps over
the insufficient hardware at very *fine/small* intervals so it all appears to the user
as if everything is working at the same time. So every app is assigned a *time
slice* and if the app exhausts the time, a mechanism called *context switching* is used
to stop the execution of the app for another app to run for some time.

__NB__: Time sharing systems are not the only ones present, there are other
types of systems that don't do this and use other mechanisms

### user mode, supervisor mode, syscalls (__isolate__)
This particular __xv6__ runs on a RISC-V CPU in qemu. CPU architecture is
important in the organization of an Operating System. It dictates how things
work on the hardware level and the way to interact with it.

The risc-v processor has three modes of execution.
1. user mode: user mode in dual mode execution. this is where user application
   run. they are not allowed to execute and access priviledged thing at the
hardware level. if they want to some hardware specific functionality they have.
Apps running in this mode are not *trusted* and so are kept in isolation from
each other, the kernel tries its best to make it so that any activity it does
only affects the apps only.
to ask the *kernel* nicely
2. supervisor mode: the famous *kernel* runs in this mode. It has the authority
   to interact with the hardware. It can execute the so-called *priviledged*
instructions to access the page table, enable or disable interrupts, handle the
interrupts, directly interacting with devices and peripherals. Provides the
*syscall* interface for user applications. It defines a *trap/interrupt vector*
datastructure that specifies the entry point for handling interrupts or *ISR*s. This is
the mechanism that makes it possible for user level apps to request the
execution of kernel functionality *syscall*. It takes care of __multiplexing__
apps on hardware __isolating__ apps from each other and facilitating the
facilitating the __interaction__ of apps with each other.
3. machine mode: the machine boots up in this mode. It is the most priviledged
   you can't get in the risc-v processor.

### kernel organization
The core question that determines how any kernel is structured is "what should be
allowed to run in supervisor/kernel mode?". And this question with many other like
performance, reliability, simplicity etc really governs how systems are
structured in general. But know this and know this @Joe-Degs, __EVERY DECISION IS
A TRADE-OFF, THERE IS RARELY A GOOD OR BAD DECISION IN AND OFF ITSELF__

But there are mainly two ways of organizing operating systems. As to which of
the two is the better one, has been the topic of discussion between OS
engineers for like half a century (this is a big black exageration).
1. __monolithic kernel__: the whole or most of the OS has direct access to the
   hardware. They execute in *priviledged* mode. this makes it easy to make the
different parts interact with each other.
2. __microkernel__: the main kernel runs in supervisor mode and most of the
   other services like file systems, device drivers etc run in user mode. They
run as services that communicate using *IPC*. They are called *servers*

Generally the most important things to know cut accross whether it is
monolithic or micro kernel. Call them the atoms of every OS if you will, if you
understand them you make the right tradeoffs to satisfy your need.
- register/stacks
- syscalls
- dual mode execution
- I/O, DMA and I/O interaction instructions
- exceptions and faults
- pagetables and virtual addressing
- TLB
- cache lines
- atomic instructions and operations

Lock this down, everything else comes easy

### code organization: xv6
Kernel code can be found in the `kernel/` directory and user level code can be
found in the `user/` directory.

kernel source files

| file | descriptions |
--------------------------
| entry.S | first boot instructions |
| kernelvec.S | kernel trap and timer handler |
| trampoline.S | context switching from user to kernel mode |
| main.c | control initializaition of other modules during boot |
| swtch.S | thread/context switching |
| plic.c | RISC-V interrupt controller |
| trap.c | handle and return from traps and interrupts |
| vm.c | manage page tables and address spaces
| kalloc.c | physical page allocator |
| sleeplock.c | locks that yield cpu |
| spinlock.c | locks that do not yield cpu |
| proc.c | processes and scheduling |
| bio.c | disk block cache |
| console.c | keyboard and screen |
| exec.c | exec syscall |
| file.c | file descriptor |
| fs.c | filesytem |
| log.c | filesystem logging |
| pipe.c | pipe support |
| start.c | early machine boot code |
| syscall.c | syscall handler/dispatcher |
| sysfile.c | file related syscalls
| sysproc.c | process related syscalls |
| uart.c | serial port console device driver |
| virtio_disk.c | disk device driver |
