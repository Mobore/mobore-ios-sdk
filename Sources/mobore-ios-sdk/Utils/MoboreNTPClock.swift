import Foundation
import OpenTelemetrySdk
import os.log
#if !os(watchOS)
import Kronos
#endif

class MoboreSuccessLogOnce {
  static let run: Void = {
    let logger  = OSLog(subsystem: "com.mobore.MoboreIosSdk", category: "NTPClock")
    os_log("NTPClock is now being used for signal timestamps.", log: logger, type: .info)
    return ()
  }()
}

class MoboreFailureLogOnce {
  static let run: Void = {
    let logger  = OSLog(subsystem: "com.mobore.MoboreIosSdk", category: "NTPClock")
    os_log("NTPClock is unavailable. Using system clock as fallback for signal timestamps.", log: logger, type: .info)
    return()
  }()
}

class MoboreNTPClock: OpenTelemetrySdk.Clock {
  var now: Date {
    #if !os(watchOS)
    if let date = Kronos.Clock.now {
      MoboreSuccessLogOnce.run
      return date
    }
    MoboreFailureLogOnce.run
    #endif
    return Date()
  }
}
