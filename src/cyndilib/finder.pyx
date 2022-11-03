from cython.operator cimport dereference

import time
import threading

cdef class Source:
    def __cinit__(self):
        self.parent = None
        self.ptr = NULL
        self.name = None
        self.valid = False

    @staticmethod
    cdef Source create(Finder parent, NDIlib_source_t* ptr, cpp_string cpp_name, str name):
        cdef Source obj = Source()
        obj.parent = parent
        obj.cpp_name = cpp_name
        obj.name = name
        obj._set_ptr(ptr)
        return obj

    @property
    def program_tally(self):
        return self.tally.on_program

    @property
    def preview_tally(self):
        return self.tally.on_preview

    cpdef set_program_tally(self, bint value):
        self.tally.on_program = value

    cpdef set_preview_tally(self, bint value):
        self.tally.on_preview = value

    cdef void _set_tally(self, bint program, bint preview) nogil except *:
        self.tally.on_program = program
        self.tally.on_preview = preview

    cpdef bint update(self):
        self._check_ptr()
        return self.valid

    cdef void _check_ptr(self) nogil except *:
        cdef NDIlib_source_t* ptr
        ptr = self.parent._get_source_ptr(self.cpp_name)
        if ptr != self.ptr:
            self._set_ptr(ptr)

    cdef void _set_ptr(self, NDIlib_source_t* ptr) nogil except *:
        self.ptr = ptr
        self.valid = self.ptr is not NULL

    cdef void _invalidate(self) nogil except *:
        self._set_ptr(NULL)

    def __repr__(self):
        s = '' if self.valid else '(invalid)'
        return f'<Source: {s} "{self}">'
    def __str__(self):
        return self.name


cdef class Finder:
    # cdef NDIlib_find_instance_t find_p
    # cdef NDIlib_source_t* source_ptr
    # cdef readonly list source_names

    def __init__(self):
        # self.source_names = []
        self.source_obj_map = {}
        self.lock = RLock()
        self.notify = Condition(self.lock)
        self.num_sources = 0
        self._initial_source_get = True
        self.build_finder()
        self.finder_thread = None
        self.finder_thread_running = Event()
        self.change_callback = Callback()

    def __dealloc__(self):
        cdef NDIlib_find_instance_t p = self.find_p
        if p != NULL:
            self.find_p = NULL
            NDIlib_find_destroy(p)

    def open(self):
        assert self.finder_thread is None
        self.finder_thread = FinderThread(self)
        self.finder_thread.start()
        self.finder_thread_running.wait()

    def close(self):
        assert self.finder_thread is not None
        t = self.finder_thread
        self.finder_thread = None
        t.stop()
        t.join()

    cpdef get_source_names(self):
        cdef list result = []
        cdef cpp_string cppname
        cdef str name
        with self.notify:
            for cppname in self.source_names:
                name = cppname.decode('UTF-8')
                result.append(name)
        return result

    def iter_sources(self):
        with self.notify:
            yield from self.source_obj_map.values()

    cpdef Source get_source(self, str name):
        return self.source_obj_map.get(name)

    cdef NDIlib_source_t* _get_source_ptr(self, cpp_string name) nogil except *:
        cdef NDIlib_source_t* result
        if self.source_ptr_map.count(name) > 0:
            result = self.source_ptr_map[name]
        else:
            result = NULL
        return result

    def __len__(self):
        return self.num_sources

    def set_change_callback(self, object cb):
        self.change_callback.set_callback(cb)

    cdef void _trigger_callback(self) nogil except *:
        if not self.change_callback.has_callback:
            return
        with gil:
            self.change_callback.trigger_callback()

    def update_sources(self):
        with self.notify:
            self._update_sources()
            return self.get_source_names()

    cdef bint _update_sources(self) except *:
        self.__notify_acquire()
        # self._lock.lock()
        cdef bint changed = False
        # cdef unique_lock[mutex]* lk = new unique_lock[mutex](self.lock)
        cdef uint32_t n_sources = 0
        cdef const NDIlib_source_t* src_p = NDIlib_find_get_current_sources(self.find_p, &n_sources)
        cdef cpp_string name
        cdef size_t i

        cdef cpp_str_set missing_source_names
        for name in self.source_names:
            missing_source_names.insert(name)

        self.source_names.clear()
        cdef const NDIlib_source_t* src_cn
        cdef NDIlib_source_t* src

        cdef str pyname
        cdef source_ptr_pair_t ptr_pair
        cdef Source src_obj

        for i in range(n_sources):
            src_c = &(src_p[i])
            src = <NDIlib_source_t*> &(src_c)[0]
            name = cpp_string(src.p_ndi_name)
            pyname = name.decode('UTF-8')
            if self.source_ptr_map.count(name) > 0:
                self.source_ptr_map.erase(name)
            else:
                changed = True
            ptr_pair = source_ptr_pair_t(name, src)
            self.source_ptr_map.insert(ptr_pair)
            if pyname in self.source_obj_map:
                src_obj = self.source_obj_map[pyname]
                src_obj._set_ptr(src)
            else:
                src_obj = Source.create(self, src, name, pyname)
                self.source_obj_map[pyname] = src_obj
            missing_source_names.erase(name)
            self.source_names.push_back(name)

        if missing_source_names.size() > 0:
            changed = True
        for name in missing_source_names:
            self.source_ptr_map.erase(name)
            pyname = name.decode('UTF-8')
            src_obj = self.source_obj_map[pyname]
            src_obj._invalidate()

        self._initial_source_get = False
        self.num_sources = n_sources
        if changed:
            self.__notify_notify_and_release()
            self._trigger_callback()
        else:
            self.__notify_release()
        return changed

    def wait(self, timeout=None):
        if timeout is None:
            self._wait()
            return True
        return self._wait_timed(timeout)

    cdef void _wait(self) nogil except *:
        with gil:
            with self.notify:
                self.notify.wait()
        # cdef unique_lock[mutex]* lk = new unique_lock[mutex](self.lock)
        # self.notify.wait(dereference(lk))
        # # lk.unlock()
        # del lk

    cdef bint _wait_timed(self, float timeout) nogil except *:
        cdef bint notified
        with gil:
            with self.notify:
                notified = self.notify.wait(timeout)
        return notified

    def wait_for_sources(self, float timeout):
        cdef uint32_t timeout_ms = int(timeout * 1000)
        return self._wait_for_sources(timeout_ms)

    cdef bint _wait_for_sources(self, uint32_t timeout_ms) except *:
        cdef bint changed
        # with gil:
        #     self.notify.acquire()
        if self._initial_source_get:
            changed = self._update_sources()
        else:
            changed = NDIlib_find_wait_for_sources(self.find_p, timeout_ms)
            if changed:
                self._update_sources()
        return changed

        # cdef unique_lock[mutex]* lk
        # if changed:
        #     self._update_sources()
        # else:
        #     lk = new unique_lock[mutex](self.lock)
        #     self.notify.notify_all()
        #     del lk

    cdef void build_finder(self) except *:
        cdef NDIlib_find_create_t find_settings = [True, NULL, NULL]
        self.find_p = NDIlib_find_create_v2(&find_settings)
        if self.find_p == NULL:
            raise MemoryError()

    cdef void __notify_acquire(self) nogil except *:
        with gil:
            self.notify.acquire()

    cdef void __notify_notify(self) nogil except *:
        with gil:
            self.notify.notify_all()

    cdef void __notify_notify_and_release(self) nogil except *:
        with gil:
            self.notify.notify_all()
            self.notify.release()

    cdef void __notify_release(self) nogil except *:
        with gil:
            self.notify.release()



cdef class FinderThreadWorker:
    cdef Finder finder
    cdef Event sleep_evt
    # cdef Event waiting
    cdef bint running
    cdef uint32_t timeout_ms

    def __init__(self, Finder finder, int timeout_ms=3000):
        self.finder = finder
        assert timeout_ms > 0
        self.timeout_ms = 1
        self.sleep_evt = Event()
        self.running = False
        # self.waiting = Event()
        print('FinderThreadWorker init')

    cdef void run(self) except *:
        cdef bint first_loop = True
        cdef bint changed
        self.running = True
        while self.running:
            if first_loop:
                self.finder.finder_thread_running.set()
                first_loop = False
            print('FinderThreadWorker waiting')
            # self.waiting.set()
            changed = self.finder._wait_for_sources(self.timeout_ms)
            print(f'FinderThreadWorker wait complete: changed={changed}')
            if self.finder.num_sources == 0:
                time.sleep(.1)
            else:
                self.sleep_evt.wait(5)
            # self.waiting.clear()
        self.finder.finder_thread_running.clear()
        self.finder = None

    def stop(self):
        self.running = False
        self.sleep_evt.set()


class FinderThread(threading.Thread):
    # cdef Finder finder
    def __init__(self, Finder finder):
        super().__init__()
        print('FinderThread init')
        self.finder = Finder
        self.worker = FinderThreadWorker(finder)
        self.running = False
        self.stopped = threading.Event()

    def run(self):
        print('FinderThread.run')
        cdef FinderThreadWorker worker = self.worker
        try:
            worker.run()
        except:
            import traceback
            traceback.print_exc()
        finally:
            self.finder = None
            self.stopped.set()

    def stop(self):
        self.worker.stop()
        self.stopped.wait()


def test():
    cdef Finder finder = Finder()
    cdef Source src_obj
    cdef NDIlib_source_t* src_ptr
    cdef cpp_string cpp_name
    cdef str name
    cdef bint notified
    def wait_for_finder():
        if len(finder):
            print('finder has sources. thread exit')
            return
        print('waitng in thread')
        finder._wait_timed(10)
        print('thread wait complete')
    try:
        print('wait_t')
        wait_t = threading.Thread(target=wait_for_finder)
        wait_t.start()
        print('finder.open start')
        finder.open()
        print('finder.open exit')
        print('waiting for wait_t')
        # notified = finder._wait_timed(5)
        wait_t.join()
        print('wait complete')
        # time.sleep(.1)
        source_names = finder.get_source_names()
        print('finder.source_names: ', source_names)

        for src_obj in finder.iter_sources():
            src_ptr = finder._get_source_ptr(src_obj.cpp_name)
            assert src_ptr == src_obj.ptr
    except:
        import traceback
        traceback.print_exc()
        raise
    finally:
        print('finder.close')
        # time.sleep(.1)
        finder.close()
        print('complete')
