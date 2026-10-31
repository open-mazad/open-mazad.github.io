import 'web_contacts_stub.dart'
    if (dart.library.html) 'web_contacts_web.dart';

Future<(String, String)?> pickPhoneDeviceContact() =>
    getPlatformDeviceContact();
