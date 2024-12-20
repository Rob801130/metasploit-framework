require 'rspec'
require 'rex/proto/kerberos/model/pkinit'

RSpec.describe 'dcerpc icpr_cert' do
  include_context 'Msf::UIDriver'
  include_context 'Msf::Simple::Framework#modules loading'

  let(:subject) do
    load_and_create_module(
      module_type: 'auxiliary',
      reference_name: 'admin/dcerpc/icpr_cert'
    )
  end

  let(:pkcs12_certificate) do
    OpenSSL::X509::Certificate.new(<<~CERTIFICATE)
      -----BEGIN CERTIFICATE-----
      MIIGyDCCBbCgAwIBAgITEAAAAEOSqzMlvbHDMgAAAAAAQzANBgkqhkiG9w0BAQsF
      ADBGMRUwEwYKCZImiZPyLGQBGRYFbG9jYWwxFjAUBgoJkiaJk/IsZAEZFgZtc2Zs
      YWIxFTATBgNVBAMTDG1zZmxhYi1EQy1DQTAeFw0yMjExMDIyMTI4NDZaFw0yMzEx
      MDIyMTI4NDZaMHsxFTATBgoJkiaJk/IsZAEZFgVsb2NhbDEWMBQGCgmSJomT8ixk
      ARkWBm1zZmxhYjEOMAwGA1UEAxMFVXNlcnMxFTATBgNVBAMTDEFsaWNlIExpZGRs
      ZTEjMCEGCSqGSIb3DQEJARYUYWxpZGRsZUBtc2ZsYWIubG9jYWwwggEiMA0GCSqG
      SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDjPSFrdevPYsMZMueAwrSqpyYbLGlvXRA9
      j2x7D/gUVZI7O01j6CpMWZ3vbxktL/69Y3VRI2WGu/vLaaIJtmtdjyJSMCLZebfg
      6KpvO1O7U5gAKYwyk0+vb8KNypUzYT/b+yIcrmyiFjn4IwwU2BDk+dWLrJ1rbg0l
      l1GO6wop1AzMe0gb7yMnR4L4q0E2Tad8hAkL6rhmwJZgbqn1A4eyy+4XBeIg36SD
      jIZBd34CE7qgt/vf4mfpeKt3VJmEIthnX5AEM850fN6nbwVgJYtzzpY6LEGoU3Nx
      idRhBzG7iwQm5PoHc6BDNytnwBsSFWq2Fllmk7sS6jZ+IB7wdB3nAgMBAAGjggN4
      MIIDdDAdBgNVHQ4EFgQUc3dLxeMuOboY7Mcradkczp07hCowHwYDVR0jBBgwFoAU
      uZJmsmi7m0bYQV3LFra6OLKxeNAwgcYGA1UdHwSBvjCBuzCBuKCBtaCBsoaBr2xk
      YXA6Ly8vQ049bXNmbGFiLURDLUNBLENOPURDLENOPUNEUCxDTj1QdWJsaWMlMjBL
      ZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPW1z
      ZmxhYixEQz1sb2NhbD9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2Jq
      ZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnQwgb8GCCsGAQUFBwEBBIGyMIGv
      MIGsBggrBgEFBQcwAoaBn2xkYXA6Ly8vQ049bXNmbGFiLURDLUNBLENOPUFJQSxD
      Tj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1
      cmF0aW9uLERDPW1zZmxhYixEQz1sb2NhbD9jQUNlcnRpZmljYXRlP2Jhc2U/b2Jq
      ZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTAOBgNVHQ8BAf8EBAMCBaAw
      PQYJKwYBBAGCNxUHBDAwLgYmKwYBBAGCNxUIgfjYFYbPvgqC9Z0sgZzVVILrlEwX
      hei+d4bf3X4CAWQCAQQwNQYDVR0lBC4wLAYIKwYBBQUHAwQGCisGAQQBgjcKAwQG
      CCsGAQUFBwMCBgorBgEEAYI3FAIBMEMGCSsGAQQBgjcVCgQ2MDQwCgYIKwYBBQUH
      AwQwDAYKKwYBBAGCNwoDBDAKBggrBgEFBQcDAjAMBgorBgEEAYI3FAIBMEUGA1Ud
      EQQ+MDygJAYKKwYBBAGCNxQCA6AWDBRhbGlkZGxlQG1zZmxhYi5sb2NhbIEUYWxp
      ZGRsZUBtc2ZsYWIubG9jYWwwTwYJKwYBBAGCNxkCBEIwQKA+BgorBgEEAYI3GQIB
      oDAELlMtMS01LTIxLTM0MDI1ODcyODktMTQ4ODc5ODUzMi0zNjE4Mjk2OTkzLTEx
      MDYwRAYJKoZIhvcNAQkPBDcwNTAOBggqhkiG9w0DAgICAIAwDgYIKoZIhvcNAwQC
      AgCAMAcGBSsOAwIHMAoGCCqGSIb3DQMHMA0GCSqGSIb3DQEBCwUAA4IBAQCJsrOx
      2GGeRXBYWCMkQ2xPCndIXCvAo/V4N3xYsWzYqKMvW465TTtKzauKOw6K2FJr+uIp
      rSKNWA+YBWFUw9mwnGOKs21LJQ6RIL6EDKS3UdHo3Ajp/mTxhlroI2oUuPEWCScN
      3HTRKEiQxX+XPe6ANAhlHLBBrE+Znn3tXv/YlXHESpRBOeVtDil8tTvEEY8X+PmL
      bvHYmTfCdQ3IzwG6vjAcuqys4n9cWqeNYLIOYGpuD1BHnqvB/erCY/289VlfYXMu
      bDBUHpLBTwS4v+hdWByWlyFo3TLCNYi0OaZ/vI1nmiEqUKbPS70M54E+oDDaIrwQ
      MPqLl/D4OpKpcKz8
      -----END CERTIFICATE-----
    CERTIFICATE
  end

  let(:pkcs12_key) do
    OpenSSL::PKey::RSA.new(<<~KEY)
      -----BEGIN RSA PRIVATE KEY-----
      MIIEpAIBAAKCAQEA4z0ha3Xrz2LDGTLngMK0qqcmGyxpb10QPY9sew/4FFWSOztN
      Y+gqTFmd728ZLS/+vWN1USNlhrv7y2miCbZrXY8iUjAi2Xm34OiqbztTu1OYACmM
      MpNPr2/CjcqVM2E/2/siHK5sohY5+CMMFNgQ5PnVi6yda24NJZdRjusKKdQMzHtI
      G+8jJ0eC+KtBNk2nfIQJC+q4ZsCWYG6p9QOHssvuFwXiIN+kg4yGQXd+AhO6oLf7
      3+Jn6Xird1SZhCLYZ1+QBDPOdHzep28FYCWLc86WOixBqFNzcYnUYQcxu4sEJuT6
      B3OgQzcrZ8AbEhVqthZZZpO7Euo2fiAe8HQd5wIDAQABAoIBAEGT5a4eZMP/q2/9
      OcP17K+G9z9GTNMfl008s8C79grgOwgu8AGSAYrxHdv4QtrAjBJZvoSA447Dd0HX
      pTSKWWexo+T2EUiTkNYuLulUxLA9ypLZaqU5z/hAF3RV70LZoNU6HzkJuT35jhcm
      /hiR1iZOVyss0G0tYEvl5FqLR+6TwQ+fT1LIszXvX0Fmhz2Lpun90LLBH4qqsrKs
      5eFFEXetwJu4oyoM3yGEWTVJagGRC8grf4mWoh8+7ZPkMVUTgV05Z//AhdDDhPhx
      VV8YK/F20NTdRn+FNYSMW3IlzT7ezYn6B8SteFmN+WHBhgV2Bcdz4T8WuOjU5m8h
      SOs+KOkCgYEA/YXqnmirjdSHyBl1RGNDe2+BcR5KFIPimhSpbM5vjb9/i9mjHA94
      MkLsMXVp28AugFZ3mQY20JvNOEssNtybsLXeV9GDAbP6tZaONdHUSTqnpygxglZX
      xda6vKBsoPUQIRjMUCqSGFW/ZLlkbT5Xr/wudJiQ73zJ/qbHuW+fIQUCgYEA5XV5
      hIQ6LROVajdKViikBpbEKFwNyarFqDGgAh6QzI4hPeBn8iTy+C69O8048ahp8K4g
      m71PjWyLPMZtQ+zAZDOScojaAhsOt+UPId/BEBCkorTTWolVm8uJ/kjx9cF8FgiJ
      /NA1V+qRHZ/SdRzmmpYKe0EJk59cGKeU7WToJvsCgYEAsfguSWGE/J1za/6jGYzt
      NFuEbJosutYSXsOeY+lO2hzSNqRjIjGh2Patw9J+q2rvudv5PQzlse+NUrVCpoib
      KqOhH9jNtIZZutujnRhdg8KPKoLGro5aM2GX2Q5s81jVJ8a2tpgL0tVu9BBI9X9M
      IxhOrD7lj5j0W7VMg1peRNkCgYBBoVUtgwiExhoxdDkN5bfsrojSpmnHKdI5JmCG
      2qk96NU3No1kpA7ez7eOeEd2T15l2dg303ECmW5F5tdv2zK4NkwH+H6qpYSTMrAe
      VzqIVspQQ3pEZg2XbyM8GS8jxMCyKKUXK5JmYBA7se/nUWngA1RiJpsPn0AfSSd+
      syL3qwKBgQD423ueq9DouleYCK1tpFGZSyCQ8ER/X0zv92g9v6ecRLTrwhdCe2o8
      aW/QRplhZZFK4XYtwn4BlD+IYylbIUZwyD6HIHE3xCkADuSTFwhyDdzet1+oaSxO
      C31WYyAVgMWh7+0BJbAY2x7yVa0+1XQn0i2TpVQgaUx9/SNBaLeDoA==
      -----END RSA PRIVATE KEY-----
    KEY
  end

  let(:x509_csr) do
    OpenSSL::X509::Request.new(<<~REQUEST)
      -----BEGIN CERTIFICATE REQUEST-----
      MIICVzCCAT8CAQAwEjEQMA4GA1UEAwwHYWxpZGRsZTCCASIwDQYJKoZIhvcNAQEB
      BQADggEPADCCAQoCggEBAOM9IWt1689iwxky54DCtKqnJhssaW9dED2PbHsP+BRV
      kjs7TWPoKkxZne9vGS0v/r1jdVEjZYa7+8tpogm2a12PIlIwItl5t+Doqm87U7tT
      mAApjDKTT69vwo3KlTNhP9v7IhyubKIWOfgjDBTYEOT51YusnWtuDSWXUY7rCinU
      DMx7SBvvIydHgvirQTZNp3yECQvquGbAlmBuqfUDh7LL7hcF4iDfpIOMhkF3fgIT
      uqC3+9/iZ+l4q3dUmYQi2GdfkAQzznR83qdvBWAli3POljosQahTc3GJ1GEHMbuL
      BCbk+gdzoEM3K2fAGxIVarYWWWaTuxLqNn4gHvB0HecCAwEAAaAAMA0GCSqGSIb3
      DQEBCwUAA4IBAQAyU7goEqpmHfulRkaMAtna+7mpVdUsuGXidsP2AFyDmiBOUtR/
      gQoXeTwWQ62vKSmD0+gSnxDbokq4T8hif/cR8WZ1jZQXE0JR9FPI/qGs/6D5e56S
      b7W3buC6UuON58pJmtrX7PtNUGg0FOn6jGB1jwEHtc+4sel24j7VMfzt3nuY/KTD
      abGLQioi9iaVEbJ6pKmBaHGcEswFiqGBGWI1zrSVIYyNy67SK3/P3RWyHHNJeS2a
      x7RMqHkWOXXjxqbM68i6tCL+2NstTzXI6mQkXWkOXU8d39wn/MqLyPdY0ZM7Lv/y
      i506vK8iofDDYoHxz8YwaPU1DOCfu+T83nPg
      -----END CERTIFICATE REQUEST-----
    REQUEST
  end

  let(:content_info) do
    Rex::Proto::CryptoAsn1::Cms::ContentInfo.parse(
      "\x30\x82\x0b\x71\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x07\x02\xa0\x82\x0b" \
      "\x62\x30\x82\x0b\x5e\x02\x01\x03\x31\x0d\x30\x0b\x06\x09\x60\x86\x48\x01" \
      "\x65\x03\x04\x02\x01\x30\x82\x02\x6c\x06\x07\x2b\x06\x01\x05\x02\x03\x01" \
      "\xa0\x82\x02\x5f\x04\x82\x02\x5b\x30\x82\x02\x57\x30\x82\x01\x3f\x02\x01" \
      "\x00\x30\x12\x31\x10\x30\x0e\x06\x03\x55\x04\x03\x0c\x07\x61\x6c\x69\x64" \
      "\x64\x6c\x65\x30\x82\x01\x22\x30\x0d\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01" \
      "\x01\x01\x05\x00\x03\x82\x01\x0f\x00\x30\x82\x01\x0a\x02\x82\x01\x01\x00" \
      "\xe3\x3d\x21\x6b\x75\xeb\xcf\x62\xc3\x19\x32\xe7\x80\xc2\xb4\xaa\xa7\x26" \
      "\x1b\x2c\x69\x6f\x5d\x10\x3d\x8f\x6c\x7b\x0f\xf8\x14\x55\x92\x3b\x3b\x4d" \
      "\x63\xe8\x2a\x4c\x59\x9d\xef\x6f\x19\x2d\x2f\xfe\xbd\x63\x75\x51\x23\x65" \
      "\x86\xbb\xfb\xcb\x69\xa2\x09\xb6\x6b\x5d\x8f\x22\x52\x30\x22\xd9\x79\xb7" \
      "\xe0\xe8\xaa\x6f\x3b\x53\xbb\x53\x98\x00\x29\x8c\x32\x93\x4f\xaf\x6f\xc2" \
      "\x8d\xca\x95\x33\x61\x3f\xdb\xfb\x22\x1c\xae\x6c\xa2\x16\x39\xf8\x23\x0c" \
      "\x14\xd8\x10\xe4\xf9\xd5\x8b\xac\x9d\x6b\x6e\x0d\x25\x97\x51\x8e\xeb\x0a" \
      "\x29\xd4\x0c\xcc\x7b\x48\x1b\xef\x23\x27\x47\x82\xf8\xab\x41\x36\x4d\xa7" \
      "\x7c\x84\x09\x0b\xea\xb8\x66\xc0\x96\x60\x6e\xa9\xf5\x03\x87\xb2\xcb\xee" \
      "\x17\x05\xe2\x20\xdf\xa4\x83\x8c\x86\x41\x77\x7e\x02\x13\xba\xa0\xb7\xfb" \
      "\xdf\xe2\x67\xe9\x78\xab\x77\x54\x99\x84\x22\xd8\x67\x5f\x90\x04\x33\xce" \
      "\x74\x7c\xde\xa7\x6f\x05\x60\x25\x8b\x73\xce\x96\x3a\x2c\x41\xa8\x53\x73" \
      "\x71\x89\xd4\x61\x07\x31\xbb\x8b\x04\x26\xe4\xfa\x07\x73\xa0\x43\x37\x2b" \
      "\x67\xc0\x1b\x12\x15\x6a\xb6\x16\x59\x66\x93\xbb\x12\xea\x36\x7e\x20\x1e" \
      "\xf0\x74\x1d\xe7\x02\x03\x01\x00\x01\xa0\x00\x30\x0d\x06\x09\x2a\x86\x48" \
      "\x86\xf7\x0d\x01\x01\x0b\x05\x00\x03\x82\x01\x01\x00\x32\x53\xb8\x28\x12" \
      "\xaa\x66\x1d\xfb\xa5\x46\x46\x8c\x02\xd9\xda\xfb\xb9\xa9\x55\xd5\x2c\xb8" \
      "\x65\xe2\x76\xc3\xf6\x00\x5c\x83\x9a\x20\x4e\x52\xd4\x7f\x81\x0a\x17\x79" \
      "\x3c\x16\x43\xad\xaf\x29\x29\x83\xd3\xe8\x12\x9f\x10\xdb\xa2\x4a\xb8\x4f" \
      "\xc8\x62\x7f\xf7\x11\xf1\x66\x75\x8d\x94\x17\x13\x42\x51\xf4\x53\xc8\xfe" \
      "\xa1\xac\xff\xa0\xf9\x7b\x9e\x92\x6f\xb5\xb7\x6e\xe0\xba\x52\xe3\x8d\xe7" \
      "\xca\x49\x9a\xda\xd7\xec\xfb\x4d\x50\x68\x34\x14\xe9\xfa\x8c\x60\x75\x8f" \
      "\x01\x07\xb5\xcf\xb8\xb1\xe9\x76\xe2\x3e\xd5\x31\xfc\xed\xde\x7b\x98\xfc" \
      "\xa4\xc3\x69\xb1\x8b\x42\x2a\x22\xf6\x26\x95\x11\xb2\x7a\xa4\xa9\x81\x68" \
      "\x71\x9c\x12\xcc\x05\x8a\xa1\x81\x19\x62\x35\xce\xb4\x95\x21\x8c\x8d\xcb" \
      "\xae\xd2\x2b\x7f\xcf\xdd\x15\xb2\x1c\x73\x49\x79\x2d\x9a\xc7\xb4\x4c\xa8" \
      "\x79\x16\x39\x75\xe3\xc6\xa6\xcc\xeb\xc8\xba\xb4\x22\xfe\xd8\xdb\x2d\x4f" \
      "\x35\xc8\xea\x64\x24\x5d\x69\x0e\x5d\x4f\x1d\xdf\xdc\x27\xfc\xca\x8b\xc8" \
      "\xf7\x58\xd1\x93\x3b\x2e\xff\xf2\x8b\x9d\x3a\xbc\xaf\x22\xa1\xf0\xc3\x62" \
      "\x81\xf1\xcf\xc6\x30\x68\xf5\x35\x0c\xe0\x9f\xbb\xe4\xfc\xde\x73\xe0\xa0" \
      "\x82\x06\xcc\x30\x82\x06\xc8\x30\x82\x05\xb0\xa0\x03\x02\x01\x02\x02\x13" \
      "\x10\x00\x00\x00\x43\x92\xab\x33\x25\xbd\xb1\xc3\x32\x00\x00\x00\x00\x00" \
      "\x43\x30\x0d\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x01\x0b\x05\x00\x30\x46" \
      "\x31\x15\x30\x13\x06\x0a\x09\x92\x26\x89\x93\xf2\x2c\x64\x01\x19\x16\x05" \
      "\x6c\x6f\x63\x61\x6c\x31\x16\x30\x14\x06\x0a\x09\x92\x26\x89\x93\xf2\x2c" \
      "\x64\x01\x19\x16\x06\x6d\x73\x66\x6c\x61\x62\x31\x15\x30\x13\x06\x03\x55" \
      "\x04\x03\x13\x0c\x6d\x73\x66\x6c\x61\x62\x2d\x44\x43\x2d\x43\x41\x30\x1e" \
      "\x17\x0d\x32\x32\x31\x31\x30\x32\x32\x31\x32\x38\x34\x36\x5a\x17\x0d\x32" \
      "\x33\x31\x31\x30\x32\x32\x31\x32\x38\x34\x36\x5a\x30\x7b\x31\x15\x30\x13" \
      "\x06\x0a\x09\x92\x26\x89\x93\xf2\x2c\x64\x01\x19\x16\x05\x6c\x6f\x63\x61" \
      "\x6c\x31\x16\x30\x14\x06\x0a\x09\x92\x26\x89\x93\xf2\x2c\x64\x01\x19\x16" \
      "\x06\x6d\x73\x66\x6c\x61\x62\x31\x0e\x30\x0c\x06\x03\x55\x04\x03\x13\x05" \
      "\x55\x73\x65\x72\x73\x31\x15\x30\x13\x06\x03\x55\x04\x03\x13\x0c\x41\x6c" \
      "\x69\x63\x65\x20\x4c\x69\x64\x64\x6c\x65\x31\x23\x30\x21\x06\x09\x2a\x86" \
      "\x48\x86\xf7\x0d\x01\x09\x01\x16\x14\x61\x6c\x69\x64\x64\x6c\x65\x40\x6d" \
      "\x73\x66\x6c\x61\x62\x2e\x6c\x6f\x63\x61\x6c\x30\x82\x01\x22\x30\x0d\x06" \
      "\x09\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01\x05\x00\x03\x82\x01\x0f\x00\x30" \
      "\x82\x01\x0a\x02\x82\x01\x01\x00\xe3\x3d\x21\x6b\x75\xeb\xcf\x62\xc3\x19" \
      "\x32\xe7\x80\xc2\xb4\xaa\xa7\x26\x1b\x2c\x69\x6f\x5d\x10\x3d\x8f\x6c\x7b" \
      "\x0f\xf8\x14\x55\x92\x3b\x3b\x4d\x63\xe8\x2a\x4c\x59\x9d\xef\x6f\x19\x2d" \
      "\x2f\xfe\xbd\x63\x75\x51\x23\x65\x86\xbb\xfb\xcb\x69\xa2\x09\xb6\x6b\x5d" \
      "\x8f\x22\x52\x30\x22\xd9\x79\xb7\xe0\xe8\xaa\x6f\x3b\x53\xbb\x53\x98\x00" \
      "\x29\x8c\x32\x93\x4f\xaf\x6f\xc2\x8d\xca\x95\x33\x61\x3f\xdb\xfb\x22\x1c" \
      "\xae\x6c\xa2\x16\x39\xf8\x23\x0c\x14\xd8\x10\xe4\xf9\xd5\x8b\xac\x9d\x6b" \
      "\x6e\x0d\x25\x97\x51\x8e\xeb\x0a\x29\xd4\x0c\xcc\x7b\x48\x1b\xef\x23\x27" \
      "\x47\x82\xf8\xab\x41\x36\x4d\xa7\x7c\x84\x09\x0b\xea\xb8\x66\xc0\x96\x60" \
      "\x6e\xa9\xf5\x03\x87\xb2\xcb\xee\x17\x05\xe2\x20\xdf\xa4\x83\x8c\x86\x41" \
      "\x77\x7e\x02\x13\xba\xa0\xb7\xfb\xdf\xe2\x67\xe9\x78\xab\x77\x54\x99\x84" \
      "\x22\xd8\x67\x5f\x90\x04\x33\xce\x74\x7c\xde\xa7\x6f\x05\x60\x25\x8b\x73" \
      "\xce\x96\x3a\x2c\x41\xa8\x53\x73\x71\x89\xd4\x61\x07\x31\xbb\x8b\x04\x26" \
      "\xe4\xfa\x07\x73\xa0\x43\x37\x2b\x67\xc0\x1b\x12\x15\x6a\xb6\x16\x59\x66" \
      "\x93\xbb\x12\xea\x36\x7e\x20\x1e\xf0\x74\x1d\xe7\x02\x03\x01\x00\x01\xa3" \
      "\x82\x03\x78\x30\x82\x03\x74\x30\x1d\x06\x03\x55\x1d\x0e\x04\x16\x04\x14" \
      "\x73\x77\x4b\xc5\xe3\x2e\x39\xba\x18\xec\xc7\x2b\x69\xd9\x1c\xce\x9d\x3b" \
      "\x84\x2a\x30\x1f\x06\x03\x55\x1d\x23\x04\x18\x30\x16\x80\x14\xb9\x92\x66" \
      "\xb2\x68\xbb\x9b\x46\xd8\x41\x5d\xcb\x16\xb6\xba\x38\xb2\xb1\x78\xd0\x30" \
      "\x81\xc6\x06\x03\x55\x1d\x1f\x04\x81\xbe\x30\x81\xbb\x30\x81\xb8\xa0\x81" \
      "\xb5\xa0\x81\xb2\x86\x81\xaf\x6c\x64\x61\x70\x3a\x2f\x2f\x2f\x43\x4e\x3d" \
      "\x6d\x73\x66\x6c\x61\x62\x2d\x44\x43\x2d\x43\x41\x2c\x43\x4e\x3d\x44\x43" \
      "\x2c\x43\x4e\x3d\x43\x44\x50\x2c\x43\x4e\x3d\x50\x75\x62\x6c\x69\x63\x25" \
      "\x32\x30\x4b\x65\x79\x25\x32\x30\x53\x65\x72\x76\x69\x63\x65\x73\x2c\x43" \
      "\x4e\x3d\x53\x65\x72\x76\x69\x63\x65\x73\x2c\x43\x4e\x3d\x43\x6f\x6e\x66" \
      "\x69\x67\x75\x72\x61\x74\x69\x6f\x6e\x2c\x44\x43\x3d\x6d\x73\x66\x6c\x61" \
      "\x62\x2c\x44\x43\x3d\x6c\x6f\x63\x61\x6c\x3f\x63\x65\x72\x74\x69\x66\x69" \
      "\x63\x61\x74\x65\x52\x65\x76\x6f\x63\x61\x74\x69\x6f\x6e\x4c\x69\x73\x74" \
      "\x3f\x62\x61\x73\x65\x3f\x6f\x62\x6a\x65\x63\x74\x43\x6c\x61\x73\x73\x3d" \
      "\x63\x52\x4c\x44\x69\x73\x74\x72\x69\x62\x75\x74\x69\x6f\x6e\x50\x6f\x69" \
      "\x6e\x74\x30\x81\xbf\x06\x08\x2b\x06\x01\x05\x05\x07\x01\x01\x04\x81\xb2" \
      "\x30\x81\xaf\x30\x81\xac\x06\x08\x2b\x06\x01\x05\x05\x07\x30\x02\x86\x81" \
      "\x9f\x6c\x64\x61\x70\x3a\x2f\x2f\x2f\x43\x4e\x3d\x6d\x73\x66\x6c\x61\x62" \
      "\x2d\x44\x43\x2d\x43\x41\x2c\x43\x4e\x3d\x41\x49\x41\x2c\x43\x4e\x3d\x50" \
      "\x75\x62\x6c\x69\x63\x25\x32\x30\x4b\x65\x79\x25\x32\x30\x53\x65\x72\x76" \
      "\x69\x63\x65\x73\x2c\x43\x4e\x3d\x53\x65\x72\x76\x69\x63\x65\x73\x2c\x43" \
      "\x4e\x3d\x43\x6f\x6e\x66\x69\x67\x75\x72\x61\x74\x69\x6f\x6e\x2c\x44\x43" \
      "\x3d\x6d\x73\x66\x6c\x61\x62\x2c\x44\x43\x3d\x6c\x6f\x63\x61\x6c\x3f\x63" \
      "\x41\x43\x65\x72\x74\x69\x66\x69\x63\x61\x74\x65\x3f\x62\x61\x73\x65\x3f" \
      "\x6f\x62\x6a\x65\x63\x74\x43\x6c\x61\x73\x73\x3d\x63\x65\x72\x74\x69\x66" \
      "\x69\x63\x61\x74\x69\x6f\x6e\x41\x75\x74\x68\x6f\x72\x69\x74\x79\x30\x0e" \
      "\x06\x03\x55\x1d\x0f\x01\x01\xff\x04\x04\x03\x02\x05\xa0\x30\x3d\x06\x09" \
      "\x2b\x06\x01\x04\x01\x82\x37\x15\x07\x04\x30\x30\x2e\x06\x26\x2b\x06\x01" \
      "\x04\x01\x82\x37\x15\x08\x81\xf8\xd8\x15\x86\xcf\xbe\x0a\x82\xf5\x9d\x2c" \
      "\x81\x9c\xd5\x54\x82\xeb\x94\x4c\x17\x85\xe8\xbe\x77\x86\xdf\xdd\x7e\x02" \
      "\x01\x64\x02\x01\x04\x30\x35\x06\x03\x55\x1d\x25\x04\x2e\x30\x2c\x06\x08" \
      "\x2b\x06\x01\x05\x05\x07\x03\x04\x06\x0a\x2b\x06\x01\x04\x01\x82\x37\x0a" \
      "\x03\x04\x06\x08\x2b\x06\x01\x05\x05\x07\x03\x02\x06\x0a\x2b\x06\x01\x04" \
      "\x01\x82\x37\x14\x02\x01\x30\x43\x06\x09\x2b\x06\x01\x04\x01\x82\x37\x15" \
      "\x0a\x04\x36\x30\x34\x30\x0a\x06\x08\x2b\x06\x01\x05\x05\x07\x03\x04\x30" \
      "\x0c\x06\x0a\x2b\x06\x01\x04\x01\x82\x37\x0a\x03\x04\x30\x0a\x06\x08\x2b" \
      "\x06\x01\x05\x05\x07\x03\x02\x30\x0c\x06\x0a\x2b\x06\x01\x04\x01\x82\x37" \
      "\x14\x02\x01\x30\x45\x06\x03\x55\x1d\x11\x04\x3e\x30\x3c\xa0\x24\x06\x0a" \
      "\x2b\x06\x01\x04\x01\x82\x37\x14\x02\x03\xa0\x16\x0c\x14\x61\x6c\x69\x64" \
      "\x64\x6c\x65\x40\x6d\x73\x66\x6c\x61\x62\x2e\x6c\x6f\x63\x61\x6c\x81\x14" \
      "\x61\x6c\x69\x64\x64\x6c\x65\x40\x6d\x73\x66\x6c\x61\x62\x2e\x6c\x6f\x63" \
      "\x61\x6c\x30\x4f\x06\x09\x2b\x06\x01\x04\x01\x82\x37\x19\x02\x04\x42\x30" \
      "\x40\xa0\x3e\x06\x0a\x2b\x06\x01\x04\x01\x82\x37\x19\x02\x01\xa0\x30\x04" \
      "\x2e\x53\x2d\x31\x2d\x35\x2d\x32\x31\x2d\x33\x34\x30\x32\x35\x38\x37\x32" \
      "\x38\x39\x2d\x31\x34\x38\x38\x37\x39\x38\x35\x33\x32\x2d\x33\x36\x31\x38" \
      "\x32\x39\x36\x39\x39\x33\x2d\x31\x31\x30\x36\x30\x44\x06\x09\x2a\x86\x48" \
      "\x86\xf7\x0d\x01\x09\x0f\x04\x37\x30\x35\x30\x0e\x06\x08\x2a\x86\x48\x86" \
      "\xf7\x0d\x03\x02\x02\x02\x00\x80\x30\x0e\x06\x08\x2a\x86\x48\x86\xf7\x0d" \
      "\x03\x04\x02\x02\x00\x80\x30\x07\x06\x05\x2b\x0e\x03\x02\x07\x30\x0a\x06" \
      "\x08\x2a\x86\x48\x86\xf7\x0d\x03\x07\x30\x0d\x06\x09\x2a\x86\x48\x86\xf7" \
      "\x0d\x01\x01\x0b\x05\x00\x03\x82\x01\x01\x00\x89\xb2\xb3\xb1\xd8\x61\x9e" \
      "\x45\x70\x58\x58\x23\x24\x43\x6c\x4f\x0a\x77\x48\x5c\x2b\xc0\xa3\xf5\x78" \
      "\x37\x7c\x58\xb1\x6c\xd8\xa8\xa3\x2f\x5b\x8e\xb9\x4d\x3b\x4a\xcd\xab\x8a" \
      "\x3b\x0e\x8a\xd8\x52\x6b\xfa\xe2\x29\xad\x22\x8d\x58\x0f\x98\x05\x61\x54" \
      "\xc3\xd9\xb0\x9c\x63\x8a\xb3\x6d\x4b\x25\x0e\x91\x20\xbe\x84\x0c\xa4\xb7" \
      "\x51\xd1\xe8\xdc\x08\xe9\xfe\x64\xf1\x86\x5a\xe8\x23\x6a\x14\xb8\xf1\x16" \
      "\x09\x27\x0d\xdc\x74\xd1\x28\x48\x90\xc5\x7f\x97\x3d\xee\x80\x34\x08\x65" \
      "\x1c\xb0\x41\xac\x4f\x99\x9e\x7d\xed\x5e\xff\xd8\x95\x71\xc4\x4a\x94\x41" \
      "\x39\xe5\x6d\x0e\x29\x7c\xb5\x3b\xc4\x11\x8f\x17\xf8\xf9\x8b\x6e\xf1\xd8" \
      "\x99\x37\xc2\x75\x0d\xc8\xcf\x01\xba\xbe\x30\x1c\xba\xac\xac\xe2\x7f\x5c" \
      "\x5a\xa7\x8d\x60\xb2\x0e\x60\x6a\x6e\x0f\x50\x47\x9e\xab\xc1\xfd\xea\xc2" \
      "\x63\xfd\xbc\xf5\x59\x5f\x61\x73\x2e\x6c\x30\x54\x1e\x92\xc1\x4f\x04\xb8" \
      "\xbf\xe8\x5d\x58\x1c\x96\x97\x21\x68\xdd\x32\xc2\x35\x88\xb4\x39\xa6\x7f" \
      "\xbc\x8d\x67\x9a\x21\x2a\x50\xa6\xcf\x4b\xbd\x0c\xe7\x81\x3e\xa0\x30\xda" \
      "\x22\xbc\x10\x30\xfa\x8b\x97\xf0\xf8\x3a\x92\xa9\x70\xac\xfc\x31\x82\x02" \
      "\x08\x30\x82\x02\x04\x02\x01\x01\x30\x5d\x30\x46\x31\x15\x30\x13\x06\x0a" \
      "\x09\x92\x26\x89\x93\xf2\x2c\x64\x01\x19\x16\x05\x6c\x6f\x63\x61\x6c\x31" \
      "\x16\x30\x14\x06\x0a\x09\x92\x26\x89\x93\xf2\x2c\x64\x01\x19\x16\x06\x6d" \
      "\x73\x66\x6c\x61\x62\x31\x15\x30\x13\x06\x03\x55\x04\x03\x13\x0c\x6d\x73" \
      "\x66\x6c\x61\x62\x2d\x44\x43\x2d\x43\x41\x02\x13\x10\x00\x00\x00\x43\x92" \
      "\xab\x33\x25\xbd\xb1\xc3\x32\x00\x00\x00\x00\x00\x43\x30\x0b\x06\x09\x60" \
      "\x86\x48\x01\x65\x03\x04\x02\x01\xa0\x81\x81\x30\x4e\x06\x0a\x2b\x06\x01" \
      "\x04\x01\x82\x37\x0d\x02\x01\x31\x40\x30\x3e\x1e\x1a\x00\x72\x00\x65\x00" \
      "\x71\x00\x75\x00\x65\x00\x73\x00\x74\x00\x65\x00\x72\x00\x6e\x00\x61\x00" \
      "\x6d\x00\x65\x1e\x20\x00\x4d\x00\x53\x00\x46\x00\x4c\x00\x41\x00\x42\x00" \
      "\x5c\x00\x73\x00\x6d\x00\x63\x00\x69\x00\x6e\x00\x74\x00\x79\x00\x72\x00" \
      "\x65\x30\x2f\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x09\x04\x31\x22\x04\x20" \
      "\x3f\x40\x73\xc1\x9c\x54\xeb\xbd\x4d\x4f\xab\x27\xfb\x8b\x65\x1a\x2c\x51" \
      "\x24\xf9\x97\x05\x91\x04\xaa\xf7\xbc\x6d\xfd\x07\x4d\x70\x30\x0b\x06\x09" \
      "\x2a\x86\x48\x86\xf7\x0d\x01\x01\x0b\x04\x82\x01\x00\x78\x74\xf7\xee\xef" \
      "\x89\x2f\x02\x77\xb9\xde\x87\x07\x3a\x58\x1d\x2d\xc0\xb0\x55\x33\x40\xf1" \
      "\x6f\xb6\x28\xd6\x44\xf1\xfa\x4f\xf6\x99\xe1\xdc\xb2\x2e\x49\x5b\x36\xa7" \
      "\xee\x6f\x82\x67\x27\x43\xd5\x99\x57\xc2\x83\x09\x29\xd2\xb3\x86\x9e\x6f" \
      "\x75\x78\xdb\xe3\xeb\x33\x65\xce\x7c\xd4\x8f\x65\x73\xa7\x82\xe4\x5e\x50" \
      "\xd3\xe8\x76\xd2\x43\x96\xeb\xe5\x3a\xd1\x03\x2e\xa0\x61\xd7\xf2\x6b\x9e" \
      "\x0b\x24\x11\x2a\x25\x4d\x68\x5e\x86\x9c\x9b\xe4\xaa\x6c\x5c\x5c\xfe\x54" \
      "\x26\x85\xd8\xcc\x0f\xdd\x69\x0f\xf6\xc3\x0b\x7c\xca\x23\xeb\x99\x8c\xc1" \
      "\x69\x80\x69\xd2\x14\x1b\x1b\x99\xde\x25\x59\x12\x8d\xb4\xc0\x01\x56\x32" \
      "\x91\x76\x8f\x8b\xd4\x29\x2f\x74\x3e\xca\xe0\xd1\xe8\x68\xde\x9d\x1e\x15" \
      "\xd9\x07\x41\x82\x14\x2a\xe9\x5c\x03\x81\x80\x04\xf1\x5b\xa5\xea\x21\x72" \
      "\x9d\x98\xa0\x23\x46\x25\xb7\x68\x7d\xc2\x58\x80\xfb\x1c\xbb\x76\xba\x76" \
      "\x3a\xba\x1c\xd8\x0f\xbf\x21\x36\xce\x03\x94\x8c\x13\xbd\xc7\x87\x42\x06" \
      "\x1c\x2b\xc8\x53\xd1\xa7\xba\xea\xfa\xbc\xba\x8e\xd8\x6f\x1c\x34\x28\x8b" \
      "\x87\x0d\xbf\x30\x87\xc1\x6e\xcc\x15\xb5\xd7\x2d\xe4\xe6\xa6\xaa\xe6"
    )
  end

  before(:each) do
    subject.datastore['VERBOSE'] = false
    allow(driver).to receive(:input).and_return(driver_input)
    allow(driver).to receive(:output).and_return(driver_output)
    subject.init_ui(driver_input, driver_output)
  end

  describe '#build_csr' do
    let(:result) do
      subject.send(:build_csr,
        cn: 'aliddle',
        private_key: pkcs12_key
      )
    end

    context 'when building' do
      it 'return a Request object' do
        expect(result).to be_a(OpenSSL::X509::Request)
      end

      it 'should respond to #to_der' do
        expect(result).to respond_to(:to_der)
      end

      it 'should be correct' do
        expect(result.to_der).to eq(x509_csr.to_der)
      end
    end

    context 'when passed a bad algorithm' do
      it 'raises a RuntimeError if the algorithm does not exist' do
        expect {
          subject.send(:build_csr,
            cn: 'aliddle',
            private_key: pkcs12_key,
            algorithm: 'METASPLOIT'
          )
        }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#build_on_behalf_of' do
    context 'when building' do
      let(:result) do
        subject.send(:build_on_behalf_of,
          csr: x509_csr,
          on_behalf_of: 'MSFLAB\\smcintyre',
          cert: pkcs12_certificate,
          key: pkcs12_key
        )
      end

      it 'return a ContentInfo object' do
        expect(result).to be_a(Rex::Proto::CryptoAsn1::Cms::ContentInfo)
      end

      it 'should respond to #to_der' do
        expect(result).to respond_to(:to_der)
      end

      it 'should be correct' do
        expect(result.to_der).to eq(content_info.to_der)
      end
    end

    context 'when passed a bad algorithm' do
      it 'raises an ArgumentError if the algorithm exists but can not be mapped to an OID' do
        expect {
          subject.send(:build_on_behalf_of,
            csr: x509_csr,
            on_behalf_of: 'MSFLAB\\smcintyre',
            cert: pkcs12_certificate,
            key: pkcs12_key,
            algorithm: 'MD4'
          )
        }.to raise_error(ArgumentError)
      end

      it 'raises a RuntimeError if the algorithm does not exist' do
        expect {
          subject.send(:build_on_behalf_of,
            csr: x509_csr,
            on_behalf_of: 'MSFLAB\\smcintyre',
            cert: pkcs12_certificate,
            key: pkcs12_key,
            algorithm: 'METASPLOIT'
          )
        }.to raise_error(RuntimeError)
      end
    end
  end
end
