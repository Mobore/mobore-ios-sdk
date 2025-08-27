import Foundation
import OpenTelemetrySdk
import os.log
#if !os(watchOS)
import Kronos
#endif

class SuccessLogOnce {
  static let run: Void = {
    let logger  = OSLog(subsystem: "com.mobore.MoboreIosSdk", category: "NTPClock")
    os_log("NTPClock is now being used for signal timestamps.", log: logger, type: .info)
    return ()
  }()
}

class FailureLogOnce {
  static let run: Void = {
    let logger  = OSLog(subsystem: "com.mobore.MoboreIosSdk", category: "NTPClock")
    os_log("NTPClock is unavailable. Using system clock as fallback for signal timestamps.", log: logger, type: .info)
    return()
  }()
}

class NTPClock: OpenTelemetrySdk.Clock {
  var now: Date {
    #if !os(watchOS)
    if let date = Kronos.Clock.now {
      SuccessLogOnce.run
      return date
    }
    FailureLogOnce.run
    #endif
    return Date()
  }
}
