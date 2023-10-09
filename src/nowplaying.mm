#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "Enums.h"
#import "MRContent.h"

typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary* information));
typedef Boolean (*MRMediaRemoteSendCommandFunction)(MRMediaRemoteCommand cmd, NSDictionary* userInfo);

int main(int argc, char** argv) {
    while(true)
    {
        if(argc == 1)
            return 0;

        NSString *cmdStr = [NSString stringWithUTF8String:argv[1]];

        int numKeys = argc - 2;
        NSMutableArray<NSString *> *keys = [NSMutableArray array];
        if(strcmp(argv[1], "get") == 0) {
            for(int i = 2; i < argc; i++) {
                NSString *key = [NSString stringWithUTF8String:argv[i]];
                [keys addObject:key];
            }
        }
        else
            return 0;

        CFURLRef ref = (__bridge CFURLRef) [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/MediaRemote.framework"];
        CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, ref);

        MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo = (MRMediaRemoteGetNowPlayingInfoFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
        MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary* information) {

                NSString *data = [information description];

                for(int i = 0; i < numKeys; i++) {
                NSString *propKey = [keys[i] stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[keys[i] substringToIndex:1] capitalizedString]];
                NSString *key = [NSString stringWithFormat:@"kMRMediaRemoteNowPlayingInfo%@", propKey];
                NSObject *rawValue = [information objectForKey:key];
                if(rawValue == nil) {
                printf("null\n");
                }
                else if([key isEqualToString:@"kMRMediaRemoteNowPlayingInfoArtworkData"] || [key isEqualToString:@"kMRMediaRemoteNowPlayingInfoClientPropertiesData"]) {
                    NSData *data = (NSData *) rawValue;
                    NSString *base64 = [data base64EncodedStringWithOptions:0];
                    printf("%s\n", [base64 UTF8String]);
                }
                else if([key isEqualToString:@"kMRMediaRemoteNowPlayingInfoElapsedTime"]) {
                    MRContentItem *item = [[objc_getClass("MRContentItem") alloc] initWithNowPlayingInfo:(__bridge NSDictionary *)information];
                    NSString *value = [NSString stringWithFormat:@"%f", item.metadata.calculatedPlaybackPosition];
                    const char *valueStr = [value UTF8String];
                    printf("%s\n", valueStr);
                }
                else {
                    NSString *value = [NSString stringWithFormat:@"%@", rawValue];
                    const char *valueStr = [value UTF8String];
                    printf("%s\n", valueStr);
                }
                }
                [NSApp terminate:nil];
        });

        sleep(1);

    }
}
