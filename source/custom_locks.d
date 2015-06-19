﻿module test_imports;

import core.atomic;
import core.sys.posix.pthread;

enum LockMechanism
{
    cas_default,
    cas_mo_rel_unlock,
    cas_pause_lock_and_mo_rel_unlock,
    posix,
    broken
}

struct SpinLock(LockMechanism lockMech)
{
    static if (lockMech != LockMechanism.posix)
        private shared uint the_lock = 0;
    else
        private __gshared pthread_spinlock_t the_lock;

    void initialize() shared
    {
        static if (lockMech == LockMechanism.posix)
            pthread_spin_init(&the_lock, 0);
    }

    static if (lockMech == LockMechanism.cas_default)
    {
        void lock() shared {
            while(!cas(&the_lock, 0, 1)) {}
        }

        void unlock() shared {
            atomicStore(the_lock, 0);
        }
    }
    else static if (lockMech == LockMechanism.cas_mo_rel_unlock)
    {
        void lock() shared {
            while(!cas(&the_lock, 0, 1)) { }
        }
        void unlock() shared {
            atomicStore!(MemoryOrder.rel)(the_lock, 0);
        }
    }
    else static if (lockMech == LockMechanism.cas_pause_lock_and_mo_rel_unlock)
    {
        void lock() shared {
            while(!cas(&the_lock, 0, 1)) {
                asm { rep; nop; }
            }
        }
        void unlock() shared {
            atomicStore!(MemoryOrder.rel)(the_lock, 0);
        }
    }
    else static if (lockMech == LockMechanism.posix)
    {
        void lock() shared {
            pthread_spin_lock(&this.the_lock);
        }
        
        void unlock() shared {
            pthread_spin_unlock(&this.the_lock);
        }
    }
    else static if (lockMech == LockMechanism.broken)
    {
        void lock() shared {
            while(the_lock != 0) { }
            the_lock = 1;
        }
        
        void unlock() shared {
            the_lock = 0;
        }
    }
}

struct LockGuard(T)
{
    shared T* mutex;

    this(shared T* mutex)
    {
        this.mutex = mutex;        
        mutex.lock();
    }

    ~this()
    {
        mutex.unlock();
    }
}

auto lockGuard(T)(shared T* mutex)
{
    return LockGuard!T(mutex);
}

struct LoggingLockGuard(T)
{
    this(shared T* mutex)
    {
        this.mutex = mutex;        
        mutex.lock();
        
        import std.stdio;
        //writefln("0x%x locking", getCurrentThreadId % 0xFFFFF);
        //writefln("Locking 0x%x, from 0x%x", mutex, getCurrentThreadId);
    }
    
    ~this()
    {
        mutex.unlock();
        
        import std.stdio;
        //writefln("0x%x unlocking\n", getCurrentThreadId % 0xFFFFF);
        //writefln("Unlocking 0x%x, from 0x%x", mutex, getCurrentThreadId);
    }
}

ulong getCurrentThreadId()
{
    import core.sys.posix.pthread : pthread_self, pthread_t;
    return cast(ulong)pthread_self();
}
