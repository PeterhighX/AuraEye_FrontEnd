#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "AvatarAI" asset catalog image resource.
static NSString * const ACImageNameAvatarAI AC_SWIFT_PRIVATE = @"AvatarAI";

/// The "AvatarAI2" asset catalog image resource.
static NSString * const ACImageNameAvatarAI2 AC_SWIFT_PRIVATE = @"AvatarAI2";

/// The "AvatarUser" asset catalog image resource.
static NSString * const ACImageNameAvatarUser AC_SWIFT_PRIVATE = @"AvatarUser";

/// The "AvatarUserMsg" asset catalog image resource.
static NSString * const ACImageNameAvatarUserMsg AC_SWIFT_PRIVATE = @"AvatarUserMsg";

/// The "ParkPhoto" asset catalog image resource.
static NSString * const ACImageNameParkPhoto AC_SWIFT_PRIVATE = @"ParkPhoto";

#undef AC_SWIFT_PRIVATE
