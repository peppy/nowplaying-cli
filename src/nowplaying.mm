#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "Enums.h"
#import "MRContent.h"

typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary* information));
typedef Boolean (*MRMediaRemoteSendCommandFunction)(MRMediaRemoteCommand cmd, NSDictionary* userInfo);

NSObject* getInfoForKey(NSDictionary* information, NSString* key) {
    NSString *propKey = [key stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[key substringToIndex:1] capitalizedString]];
    NSString *fullKey = [NSString stringWithFormat:@"kMRMediaRemoteNowPlayingInfo%@", propKey];
    NSObject *rawValue = [information objectForKey:fullKey];
    if(rawValue == nil) {
        return nil;
    }
    else if([fullKey isEqualToString:@"kMRMediaRemoteNowPlayingInfoArtworkData"] || [fullKey isEqualToString:@"kMRMediaRemoteNowPlayingInfoClientPropertiesData"]) {
        return (NSData *) rawValue;
    }
    else if([fullKey isEqualToString:@"kMRMediaRemoteNowPlayingInfoElapsedTime"]) {
        MRContentItem *item = [[objc_getClass("MRContentItem") alloc] initWithNowPlayingInfo:(__bridge NSDictionary *)information];
        return [NSString stringWithFormat:@"%f", item.metadata.calculatedPlaybackPosition];
    }
    else {
        return [NSString stringWithFormat:@"%@", rawValue];
    }
}

int main(int argc, char** argv) {
    while(true)
    {
        CFURLRef ref = (__bridge CFURLRef) [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/MediaRemote.framework"];
        CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, ref);

        MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo = (MRMediaRemoteGetNowPlayingInfoFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
        MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary* information) {
            NSString* title = (NSString*)getInfoForKey(information, [NSString stringWithFormat:@"title"]);
            NSString* artist = (NSString*) getInfoForKey(information, [NSString stringWithFormat:@"artist"]);
            NSString* album = (NSString*) getInfoForKey(information, [NSString stringWithFormat:@"album"]);
            NSString* userInfo = (NSString*) getInfoForKey(information, [NSString stringWithFormat:@"userInfo"]);
            NSString* artworkIdentifier = (NSString*) getInfoForKey(information, [NSString stringWithFormat:@"artworkIdentifier"]);
            artworkIdentifier = [NSString stringWithFormat:@"%lu.jpg", artworkIdentifier.hash];
            NSData* artworkData = (NSData*) getInfoForKey(information, [NSString stringWithFormat:@"artworkData"]);
            NSString* artworkDataHeight = (NSString*) getInfoForKey(information, [NSString stringWithFormat:@"artworkDataHeight"]);
            NSString* duration = (NSString*) getInfoForKey(information, [NSString stringWithFormat:@"duration"]);
            NSString* elapsedTime = (NSString*) getInfoForKey(information, [NSString stringWithFormat:@"elapsedTime"]);

            NSString* podArtURL = @"";
            NSError *error = NULL;

            // this isn't really required.
            if (userInfo != nil)
            {
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"https:[^\"]*" options:NSRegularExpressionCaseInsensitive error:&error];
                NSTextCheckingResult *match = [regex firstMatchInString:userInfo options:0 range:NSMakeRange(0, [userInfo length])];

                if (match){
                    podArtURL = [userInfo substringWithRange:[match range]];
                    podArtURL = [podArtURL stringByReplacingOccurrencesOfString:@"{w}" withString:@"256"];
                    podArtURL = [podArtURL stringByReplacingOccurrencesOfString:@"{h}" withString:@"256"];
                    podArtURL = [podArtURL stringByReplacingOccurrencesOfString:@"{f}" withString:@"jpg"];
                    podArtURL = [podArtURL stringByReplacingOccurrencesOfString:@"{c}" withString:@""];
                } 
            }

            if (artworkDataHeight != nil && artworkDataHeight.length > 0)
            {
                NSString* filePath = [NSString stringWithFormat:@"../cache/%@", artworkIdentifier];
                NSFileManager *fileManager = [NSFileManager defaultManager];
                if(![fileManager fileExistsAtPath:filePath]) {
                    if (artworkData != nil) {
                        [artworkData writeToFile:filePath options:NSDataWritingAtomic error:&error];
                    } else {
                        // having a non-null height means we have pending artwork data
                        // it may take a bit for it to arrive.
                        // don't update output until it does.
                        sleep(1);
                        return;
                    }
                }
            }

            NSArray *allStrings = 
                artist != nil && artist.length > 0 
                ? @[@"true", @"Music", title, artist, album, podArtURL, artworkIdentifier, duration, elapsedTime]
                : @[@"false"];

            NSString *joined = [allStrings componentsJoinedByString:@"\n"];
            [joined writeToFile:@"track" atomically:YES encoding:NSUTF8StringEncoding error:&error];
        });

        sleep(1);
    }
}

