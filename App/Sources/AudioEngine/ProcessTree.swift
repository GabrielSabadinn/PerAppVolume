import Darwin
import Foundation

enum ProcessTree {
    private typealias ResponsiblePIDFunction = @convention(c) (pid_t) -> pid_t

    private static let responsiblePIDFunction: ResponsiblePIDFunction? = {
        guard let handle = dlopen("/usr/lib/system/libquarantine.dylib", RTLD_NOW),
              let symbol = dlsym(handle, "responsibility_get_pid_responsible_for_pid") else { return nil }
        return unsafeBitCast(symbol, to: ResponsiblePIDFunction.self)
    }()

    static func parentPID(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }

    static func responsiblePID(of pid: pid_t) -> pid_t? {
        guard let function = responsiblePIDFunction else { return nil }
        let responsible = function(pid)
        return responsible > 0 ? responsible : nil
    }

    static func name(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }
}
