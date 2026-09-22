#import <Foundation/Foundation.h>

// Invokes activation once, after the server validates a license.
void AYLicenseGateStart(void (^activation)(void));
