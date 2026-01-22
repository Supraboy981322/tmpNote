//thank you, https://filesig.search.org/
//  for your amazing table of file header signatures
//
//script to generate the list:
//  #!/usr/bin/env bash
//  
//  (
//    set -eou pipefail
//   
//    # print this script's source
//  cat <<EOF
//  //thank you, https://filesig.search.org/
//  //  for your amazing table of file header signatures
//  //
//  //script to generate the list:
//  EOF
//  
//    # embed the script in the output
//    declare -a filename="$(echo "${0}")"
//    cat "${filename}" | sed 's|^|//  |g'
//  
//    # create the table as an exported constant
//    printf "\npub const list = [_][2][]const u8 {\n"
//  
//    # get the length of the json input
//    declare -i len=$(cat magic.json | jq '. | length')
//  
//    # iterate over the json
//    for i in $(seq 0 $((len-1))); do
//  
//      # get the header
//      declare header_R="$(cat magic.json | jq -r ".[${i}].\"Header (HEX)\"")"
//      # skip short headers
//      [[ ${#header_R} -lt 2 ]] && continue
//  
//      # get the first hex digit
//      declare -a first_dig=$(echo "${header_R}" | sed 's|'" "'.*||')
//      # remove first digit if not 2 chars (not hex, there's a few of those)
//      if [[ ${#first_dig} < 2 ]]; then
//        header_R="$(echo "${header_R}" | sed 's|.* ||')";
//      fi
//  
//      # replace the spaces with '\x' (for '\x00' formatted escape)
//      declare -a header="$(echo "\x${header_R}" | sed 's| |\\x|g')"
//      # get the file description (what it is) 
//      declare -a desc="$(cat magic.json | jq ".[${i}].\"ASCII File Description\"")"
//      # get the file class (eg: 'Picture')
//      declare -a type="$(cat magic.json | jq ".[${i}].\"File Class\"")"
//  
//      # print the object
//      printf "  .{\n    \"%s\",\n    %s,\n    %s\n  },\n" "${header}" "${desc}" "${type}"
//    done
//    # close the table
//    printf "};\n"
//  )

pub const list = [_][3][]const u8 {
  .{
    "\x00\x00\x00\x14\x66\x74\x79\x70\x69\x73\x6F\x6D",
    "MPEG-4 v1",
    "Multimedia"
  },
  .{
    "\x00\x00\x00\x00\x14\x00\x00\x00",
    "Windows Disk Image",
    "Windows"
  },
  .{
    "\x00\x00\x00\x00\x62\x31\x05\x00\x09\x00\x00\x00\x00\x20\x00\x00\x00\x09\x00\x00\x00\x00\x00\x00",
    "Bitcoin Core wallet.dat file",
    "Finance"
  },
  .{
    "\x00\x00\x00\x18\x66\x74\x79\x70",
    "MPEG-4 video_1",
    "Multimedia"
  },
  .{
    "\x00\x00\x00\x20\x66\x74\x79\x70\x4D\x34\x41",
    "Apple audio and video",
    "Multimedia"
  },
  .{
    "\x00\x00\x02\x00\x06\x04\x06\x00",
    "Lotus 1-2-3 (v1)",
    "Spreadsheet"
  },
  .{
    "\x00\x06\x15\x61\x00\x00\x00\x02\x00\x00\x04\xD2\x00\x00\x10\x00",
    "Netscape Navigator (v4) database",
    "Network"
  },
  .{
    "\x00\x0D\xBB\xA0",
    "Mbox table of contents file",
    "E-mail"
  },
  .{
    "\x00\x11",
    "FLIC animation",
    "Miscellaneous"
  },
  .{
    "\x02\x64\x73\x73",
    "Digital Speech Standard file",
    "Multimedia"
  },
  .{
    "\x03\x00\x00\x00",
    "Nokia PC Suite Content Copier file",
    "Multimedia"
  },
  .{
    "\x0A\x03\x01\x01",
    "ZSOFT Paintbrush file_2",
    "Presentation"
  },
  .{
    "\x0F\x00\xE8\x03",
    "PowerPoint presentation subheader_2",
    "Presentation"
  },
  .{
    "\x1A\x00\x00\x04\x00\x00",
    "Lotus Notes database",
    "Spreadsheet"
  },
  .{
    "\x1A\x03",
    "LH archive (old vers.-type 2)",
    "Compressed archive"
  },
  .{
    "\x1A\x0B",
    "Compressed archive file",
    "Compressed archive"
  },
  .{
    "\x21\x12",
    "AIN Compressed Archive",
    "Compressed archive"
  },
  .{
    "\x21\x42\x44\x4E",
    "Microsoft Outlook Exchange Offline Storage Folder",
    "Email"
  },
  .{
    "\x23\x20\x44\x69\x73\x6B\x20\x44",
    "VMware 4 Virtual Disk description",
    "Miscellaneous"
  },
  .{
    "\x23\x20\x4D\x69\x63\x72\x6F\x73",
    "MS Developer Studio project file",
    "Programming"
  },
  .{
    "\x23\x21\x53\x49\x4C\x4B\x0A",
    "Skype audio compression",
    "Multimedia"
  },
  .{
    "\x23\x50\x45\x43\x30\x30\x30\x31",
    "Brother-Babylock-Bernina Home Embroidery",
    "Miscellaneous"
  },
  .{
    "\x24\x46\x4C\x32\x40\x28\x23\x29",
    "SPSS Data file",
    "Miscellaneous"
  },
  .{
    "\x25\x21\x50\x53\x2D\x41\x64\x6F",
    "Encapsulated PostScript file",
    "Word processing suite"
  },
  .{
    "\x25\x21\x50\x53\x2D\x41\x64\x6F\x62\x65\x2D",
    "PostScript file",
    "Word processing suite"
  },
  .{
    "\x25\x62\x69\x74\x6D\x61\x70",
    "Fuzzy bitmap (FBM) file",
    "Picture"
  },
  .{
    "\x2E\x52\x4D\x46",
    "RealMedia streaming media",
    "Multimedia"
  },
  .{
    "\x2E\x73\x6E\x64",
    "NeXT-Sun Microsystems audio file",
    "Multimedia"
  },
  .{
    "\x34\xCD\xB2\xA1",
    "Tcpdump capture file",
    "Network"
  },
  .{
    "\x37\xE4\x53\x96\xC9\xDB\xD6\x07",
    "zisofs compressed file",
    "Compressed archive"
  },
  .{
    "\x38\x42\x50\x53",
    "Photoshop image",
    "Picture"
  },
  .{
    "\x3A\x56\x45\x52\x53\x49\x4F\x4E",
    "Surfplan kite project file",
    "Miscellaneous"
  },
  .{
    "\x3C",
    "Advanced Stream Redirector",
    "Multimedia"
  },
  .{
    "\x3C\x21\x64\x6F\x63\x74\x79\x70",
    "AOL HTML mail",
    "Email"
  },
  .{
    "\x3C\x3F\x78\x6D\x6C\x20\x76\x65\x72\x73\x69\x6F\x6E\x3D\x22\x31\x2E\x30\x22\x3F\x3E",
    "User Interface Language",
    "Miscellaneous"
  },
  .{
    "\x3C\x43\x54\x72\x61\x6E\x73\x54\x69\x6D\x65\x6C\x69\x6E\x65\x3E",
    "Picasa movie project file",
    "Multimedia"
  },
  .{
    "\x3C\x43\x73\x6F\x75\x6E\x64\x53\x79\x6E\x74\x68\x65\x73\x69\x7A",
    "Csound music",
    "Multimedia"
  },
  .{
    "\x3C\x67\x70\x78\x20\x76\x65\x72\x73\x69\x6F\x6E\x3D\x22\x31\x2E",
    "GPS Exchange (v1.1)",
    "Navigation"
  },
  .{
    "\x3F\x5F\x03\x00",
    "Windows Help file_2",
    "Windows"
  },
  .{
    "\x41\x4F\x4C\x44\x42",
    "AOL address book",
    "Network"
  },
  .{
    "\x41\x4F\x4C\x49\x44\x58",
    "AOL client preferences-settings file",
    "Network"
  },
  .{
    "\x41\x4F\x4C\x56\x4D\x31\x30\x30",
    "AOL personal file cabinet",
    "Network"
  },
  .{
    "\x41\x56\x47\x36\x5F\x49\x6E\x74",
    "AVG6 Integrity database",
    "Database"
  },
  .{
    "\x42\x4F\x4F\x4B\x4D\x4F\x42\x49",
    "Palmpilot resource file",
    "Mobile"
  },
  .{
    "\x42\x5A\x68",
    "bzip2 compressed archive",
    "Compressed archive"
  },
  .{
    "\x42\x6C\x69\x6E\x6B",
    "Blink compressed archive",
    "Compressed archive"
  },
  .{
    "\x43\x42\x46\x49\x4C\x45",
    "WordPerfect dictionary",
    "Word processing suite"
  },
  .{
    "\x43\x44\x30\x30\x31",
    "ISO-9660 CD Disc Image",
    "Compressed archive"
  },
  .{
    "\x43\x49\x53\x4F",
    "Compressed ISO CD image",
    "Compressed archive"
  },
  .{
    "\x43\x4F\x57\x44",
    "VMware 3 Virtual Disk",
    "Miscellaneous"
  },
  .{
    "\x43\x61\x6C\x63\x75\x6C\x75\x78\x20\x49\x6E\x64\x6F\x6F\x72\x20",
    "Calculux Indoor lighting project file",
    "Application"
  },
  .{
    "\x44\x42\x46\x48",
    "Palm Zire photo database",
    "Mobile"
  },
  .{
    "\x44\x56\x44",
    "DVD info file",
    "Multimedia"
  },
  .{
    "\x45\x4E\x54\x52\x59\x56\x43\x44",
    "VideoVCD-VCDImager file",
    "Miscellaneous"
  },
  .{
    "\x45\x52\x46\x53\x53\x41\x56\x45",
    "EasyRecovery Saved State file",
    "Miscellaneous"
  },
  .{
    "\x44\x53\x44\x20",
    "DSD Storage Facility audio file",
    "Multimedia"
  },
  .{
    "\x45\x50",
    "MS Document Imaging file",
    "Word processing suite"
  },
  .{
    "\x46\x4F\x52\x4D\x00",
    "Audio Interchange File",
    "Multimedia"
  },
  .{
    "\x47\x52\x49\x42",
    "General Regularly-distributed Information (GRIdded) Binary",
    "Miscellaneous"
  },
  .{
    "\x48\x44\x52\x2A\x50\x6F\x77\x65\x72\x42\x75\x69\x6C\x64\x65\x72",
    "SAP PowerBuilder integrated development environment file",
    "Programming"
  },
  .{
    "\x48\x45\x41\x44\x45\x52\x20\x52\x45\x43\x4F\x52\x44\x2A\x2A\x2A",
    "SAS Transport dataset",
    "Statistics"
  },
  .{
    "\x49\x44\x33",
    "MP3 audio file",
    "Multimedia"
  },
  .{
    "\x49\x44\x33\x03\x00\x00\x00",
    "Sprint Music Store audio",
    "Multimedia"
  },
  .{
    "\x00\x00\x00\x0C\x6A\x50\x20\x20",
    "JPEG2000 image files",
    "Picture"
  },
  .{
    "\x00\x00\x00\x1C\x66\x74\x79\x70",
    "MPEG-4 video_2",
    "Multimedia"
  },
  .{
    "\x00\x00\x00\x20\x66\x74\x79\x70",
    "3GPP2 multimedia files",
    "Multimedia"
  },
  .{
    "\x00\x00\x01\x00",
    "Windows icon|printer spool file",
    "Windows"
  },
  .{
    "\x00\x00\x01\xBA",
    "DVD video file",
    "Multimedia"
  },
  .{
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
    "Compucon-Singer embroidery design file",
    "Miscellaneous"
  },
  .{
    "\x00\x00\x02\x00",
    "QuattroPro spreadsheet",
    "Spreadsheet"
  },
  .{
    "\x00\x00\x03\xF3",
    "Amiga Hunk executable",
    "System"
  },
  .{
    "\x00\x01\x00\x00\x4D\x53\x49\x53\x41\x4D\x20\x44\x61\x74\x61\x62\x61\x73\x65",
    "Microsoft Money file",
    "Finance"
  },
  .{
    "\x00\x14\x00\x00\x01\x02",
    "BIOS details in RAM",
    "Windows"
  },
  .{
    "\x00\x6E\x1E\xF0",
    "PowerPoint presentation subheader_1",
    "Presentation"
  },
  .{
    "\x01\x00\x02\x00",
    "Webex Advanced Recording Format",
    "Video"
  },
  .{
    "\x01\x00\x39\x30",
    "Firebird and Interbase database files",
    "Database"
  },
  .{
    "\x04\x00\x00\x00",
    "INFO2 Windows recycle bin_1",
    "Windows"
  },
  .{
    "\x07\x53\x4B\x46",
    "SkinCrafter skin",
    "Miscellaneous"
  },
  .{
    "\x0A\x02\x01\x01",
    "ZSOFT Paintbrush file_1",
    "Presentation"
  },
  .{
    "\x1A\x00\x00",
    "Lotus Notes database template",
    "Spreadsheet"
  },
  .{
    "\x1A\x04",
    "LH archive (old vers.-type 3)",
    "Compressed archive"
  },
  .{
    "\x1A\x09",
    "LH archive (old vers.-type 5)",
    "Compressed archive"
  },
  .{
    "\x1A\x45\xDF\xA3\x93\x42\x82\x88",
    "Matroska stream file_2",
    "Multimedia"
  },
  .{
    "\x1A\x52\x54\x53\x20\x43\x4F\x4D",
    "Runtime Software disk image",
    "Miscellaneous"
  },
  .{
    "\x1F\x8B\x08",
    "VLC Player Skin file",
    "Miscellaneous"
  },
  .{
    "\x1F\xA0",
    "Compressed tape archive_2",
    "Compressed archive"
  },
  .{
    "\x23\x20\x54\x68\x69\x73\x20\x69\x73\x20\x61\x6E\x20\x4B\x65\x79",
    "Google Earth Keyhole Placemark file",
    "Navigation"
  },
  .{
    "\x23\x4E\x42\x46",
    "NVIDIA Scene Graph binary file",
    "Video"
  },
  .{
    "\x25\x50\x44\x46",
    "PDF file",
    "Word processing suite"
  },
  .{
    "\x2A\x2A\x2A\x20\x20\x49\x6E\x73",
    "Symantec Wise Installer log",
    "Miscellaneous"
  },
  .{
    "\x2D\x6C\x68",
    "Compressed archive",
    "Compressed archive"
  },
  .{
    "\x2E\x52\x4D\x46\x00\x00\x00\x12",
    "RealAudio file",
    "Multimedia"
  },
  .{
    "\x30\x00\x00\x00\x4C\x66\x4C\x65",
    "Windows Event Viewer file",
    "Windows"
  },
  .{
    "\x31\xBE",
    "MS Write file_1",
    "Word processing suite"
  },
  .{
    "\x37\x7A\xBC\xAF\x27\x1C",
    "7-Zip compressed file",
    "Compressed archive"
  },
  .{
    "\x3C\x3F\x78\x6D\x6C\x20\x76\x65\x72\x73\x69\x6F\x6E\x3D",
    "Windows Visual Stylesheet",
    "Programming"
  },
  .{
    "\x3C\x4D\x61\x6B\x65\x72\x46\x69",
    "Adobe FrameMaker",
    "Presentation"
  },
  .{
    "\x41\x42\x6F\x78",
    "Analog Box (ABox) circuit files",
    "Audio"
  },
  .{
    "\x41\x43\x76",
    "Steganos virtual secure drive",
    "Miscellaneous"
  },
  .{
    "\x41\x56\x49\x20\x4C\x49\x53\x54",
    "RIFF Windows Audio",
    "Multimedia"
  },
  .{
    "\x41\x72\x43\x01",
    "FreeArc compressed file",
    "Compressed archive"
  },
  .{
    "\x42\x45\x47\x49\x4E\x3A\x56\x43",
    "vCard",
    "Miscellaneous"
  },
  .{
    "\x42\x5A\x68",
    "Mac Disk image (BZ2 compressed)",
    "Compressed archive"
  },
  .{
    "\x43\x41\x54\x20",
    "EA Interchange Format File (IFF)_3",
    "Multimedia"
  },
  .{
    "\x43\x4F\x4D\x2B",
    "COM+ Catalog",
    "Miscellaneous"
  },
  .{
    "\x43\x50\x54\x37\x46\x49\x4C\x45",
    "Corel Photopaint file_1",
    "Presentation"
  },
  .{
    "\x43\x52\x45\x47",
    "Win9x registry hive",
    "Windows"
  },
  .{
    "\x43\x57\x53",
    "Shockwave Flash file",
    "Multimedia"
  },
  .{
    "\x44\x4F\x53",
    "Amiga disk file",
    "Miscellaneous"
  },
  .{
    "\x44\x53\x54\x62",
    "DST Compression",
    "Compressed archive"
  },
  .{
    "\x45\x52\x02\x00\x00",
    "Apple ISO 9660-HFS hybrid CD image",
    "Compressed archive"
  },
  .{
    "\x45\x56\x46\x32\x0D\x0A\x81",
    "EnCase Evidence File Format V2",
    "Miscellaneous"
  },
  .{
    "\x45\x86\x00\x00\x06\x00",
    "QuickBooks backup",
    "Finance"
  },
  .{
    "\x46\x4C\x56",
    "Flash video file",
    "Multimedia"
  },
  .{
    "\x46\x4F\x52\x4D",
    "IFF ANIM file",
    "Multimedia"
  },
  .{
    "\x46\x4F\x52\x4D\x00",
    "DAKX Compressed Audio",
    "Multimedia"
  },
  .{
    "\x46\x57\x53",
    "Shockwave Flash player",
    "Multimedia"
  },
  .{
    "\x47\x49\x46\x38",
    "GIF file",
    "Picture"
  },
  .{
    "\x47\x50\x41\x54",
    "GIMP pattern file",
    "Picture"
  },
  .{
    "\x49\x53\x63\x28",
    "Install Shield compressed file",
    "Compressed archive"
  },
  .{
    "\x49\x6E\x74\x65\x72\x40\x63\x74\x69\x76\x65\x20\x50\x61\x67\x65",
    "Inter@ctive Pager Backup (BlackBerry file",
    "Mobile"
  },
  .{
    "\x4A\x47\x03\x0E",
    "AOL ART file_1",
    "Picture"
  },
  .{
    "\x4B\x57\x41\x4A\x88\xF0\x27\xD1",
    "KWAJ (compressed) file",
    "Compressed archive"
  },
  .{
    "\x4C\x01",
    "MS COFF relocatable object code",
    "Windows"
  },
  .{
    "\x4C\x4E\x02\x00",
    "Windows help file_3",
    "Windows"
  },
  .{
    "\x4D\x53\x43\x46",
    "Powerpoint Packaged Presentation",
    "Presentation"
  },
  .{
    "\x49\x4D\x4D\x4D\x15\x00\x00\x00",
    "Windows 7 thumbnail_2",
    "Windows"
  },
  .{
    "\x49\x6E\x6E\x6F\x20\x53\x65\x74",
    "Inno Setup Uninstall Log",
    "Miscellaneous"
  },
  .{
    "\x4A\x41\x52\x43\x53\x00",
    "JARCS compressed archive",
    "Compressed archive"
  },
  .{
    "\x4B\x44\x4D",
    "VMware 4 Virtual Disk",
    "Miscellaneous"
  },
  .{
    "\x4B\x47\x42\x5F\x61\x72\x63\x68",
    "KGB archive",
    "Compressed archive"
  },
  .{
    "\x4C\x00\x00\x00\x01\x14\x02\x00",
    "Windows shortcut file",
    "Windows"
  },
  .{
    "\x4C\x50\x46\x20\x00\x01",
    "DeluxePaint Animation",
    "Multimedia"
  },
  .{
    "\x4D\x2D\x57\x20\x50\x6F\x63\x6B",
    "Merriam-Webster Pocket Dictionary",
    "Miscellaneous"
  },
  .{
    "\x4D\x41\x52\x43",
    "Microsoft-MSN MARC archive",
    "Compressed archive"
  },
  .{
    "\x4D\x41\x54\x4C\x41\x42\x20\x35\x2E\x30\x20\x4D\x41\x54\x2D\x66\x69\x6C\x65",
    "MATLAB v5 workspace",
    "Programming"
  },
  .{
    "\x4D\x4D\x4D\x44\x00\x00",
    "Yamaha Synthetic music Mobile Application Format",
    "Multimedia"
  },
  .{
    "\x4D\x53\x43\x46",
    "OneNote Package",
    "Windows"
  },
  .{
    "\x4D\x53\x43\x46",
    "MS Access Snapshot Viewer file",
    "Database"
  },
  .{
    "\x4D\x53\x57\x49\x4D",
    "Microsoft Windows Imaging Format",
    "Picture"
  },
  .{
    "\x4D\x56\x32\x31\x34",
    "Milestones project management file_1",
    "Miscellaneous"
  },
  .{
    "\x4D\x5A",
    "OLE object library",
    "Windows"
  },
  .{
    "\x4D\x5A",
    "Screen saver",
    "Windows"
  },
  .{
    "\x4D\x5A\x90\x00\x03\x00\x00\x00",
    "DirectShow filter",
    "Miscellaneous"
  },
  .{
    "\x4D\x69\x63\x72\x6F\x73\x6F\x66\x74\x20\x57\x69\x6E\x64\x6F\x77\x73\x20\x4D\x65\x64\x69\x61\x20\x50\x6C\x61\x79\x65\x72\x20\x2D\x2D\x20",
    "Windows Media Player playlist",
    "Multimedia"
  },
  .{
    "\x50\x4B\x03\x04",
    "StarOffice spreadsheet",
    "Spreadsheet"
  },
  .{
    "\x50\x4B\x03\x04",
    "Mozilla Browser Archive",
    "Network"
  },
  .{
    "\x50\x4B\x03\x04",
    "eXact Packager Models",
    "Miscellaneous"
  },
  .{
    "\x50\x53\x46\x12",
    "Dreamcast Sound Format",
    "Multimedia"
  },
  .{
    "\x50\x61\x56\x45",
    "Parrot Video Encapsulation",
    "Multimedia"
  },
  .{
    "\x51\x46\x49",
    "Qcow Disk Image",
    "Miscellaneous"
  },
  .{
    "\x51\x4C\x43\x4D\x66\x6D\x74\x20",
    "RIFF Qualcomm PureVoice",
    "Multimedia"
  },
  .{
    "\x52\x49\x46\x46",
    "Windows animated cursor",
    "Windows"
  },
  .{
    "\x52\x49\x46\x46",
    "CorelDraw document",
    "Presentation"
  },
  .{
    "\x52\x49\x46\x46",
    "Resource Interchange File Format",
    "Multimedia"
  },
  .{
    "\x53\x43\x48\x6C",
    "Underground Audio",
    "Multimedia"
  },
  .{
    "\x53\x49\x54\x21\x00",
    "StuffIt archive",
    "Compressed archive"
  },
  .{
    "\x56\x45\x52\x53\x49\x4F\x4E\x20",
    "Visual Basic User-defined Control file",
    "Programming"
  },
  .{
    "\x56\x65\x72\x73\x69\x6F\x6E\x20",
    "MapInfo Interchange Format file",
    "Miscellaneous"
  },
  .{
    "\x57\x04\x00\x00\x53\x50\x53\x53\x20\x74\x65\x6D\x70\x6C\x61\x74",
    "SPSS template",
    "Statistics"
  },
  .{
    "\x57\x45\x42\x50",
    "RIFF WebP",
    "Multimedia"
  },
  .{
    "\x58\x50\x44\x53",
    "SMPTE DPX file (little endian)",
    "Picture"
  },
  .{
    "\x58\x54",
    "MS Publisher",
    "Word processing suite"
  },
  .{
    "\x5A\x4F\x4F\x20",
    "ZOO compressed archive",
    "Compressed archive"
  },
  .{
    "\x5B\x66\x6C\x74\x73\x69\x6D\x2E",
    "Flight Simulator Aircraft Configuration",
    "Games"
  },
  .{
    "\x5B\x76\x65\x72\x5D",
    "Lotus AMI Pro document_2",
    "Word processing suite"
  },
  .{
    "\x64\x00\x00\x00",
    "Intel PROset-Wireless Profile",
    "Network"
  },
  .{
    "\x64\x73\x77\x66\x69\x6C\x65",
    "MS Visual Studio workspace file",
    "Programming"
  },
  .{
    "\x66\x74\x79\x70\x4D\x34\x56\x20",
    "ISO Media-MPEG v4-iTunes AVC-LC",
    "Multimedia"
  },
  .{
    "\x66\x74\x79\x70\x69\x73\x6F\x6D",
    "ISO Base Media file (MPEG-4) v1",
    "Multimedia"
  },
  .{
    "\x67\x49\x00\x00",
    "Win2000-XP printer spool file",
    "Windows"
  },
  .{
    "\x6D\x6F\x6F\x76",
    "QuickTime movie_1",
    "Multimedia"
  },
  .{
    "\x66\x72\x65\x65",
    "QuickTime movie_2",
    "Multimedia"
  },
  .{
    "\x70\x6E\x6F\x74",
    "QuickTime movie_5",
    "Multimedia"
  },
  .{
    "\x72\x69\x66\x66",
    "Sonic Foundry Acid Music File",
    "Multimedia"
  },
  .{
    "\x72\x74\x73\x70\x3A\x2F\x2F",
    "RealMedia metafile",
    "Multimedia"
  },
  .{
    "\x73\x6C\x68\x2E",
    "Allegro Generic Packfile (uncompressed)",
    "Miscellaneous"
  },
  .{
    "\x73\x7A\x65\x7A",
    "PowerBASIC Debugger Symbols",
    "Programming"
  },
  .{
    "\x74\x42\x4D\x50\x4B\x6E\x57\x72",
    "PathWay Map file",
    "Mobile"
  },
  .{
    "\x74\x72\x75\x65\x00",
    "TrueType font",
    "Windows"
  },
  .{
    "\x78\x01\x73\x0D\x62\x62\x60",
    "MacOS X image file",
    "MacOS"
  },
  .{
    "\x7C\x4B\xC3\x74\xE1\xC8\x53\xA4\x79\xB9\x01\x1D\xFC\x4F\xDD\x13",
    "Huskygram Poem or Singer embroidery",
    "Miscellaneous"
  },
  .{
    "\x7E\x45\x53\x44\x77\xF6\x85\x3E\xBF\x6A\xD2\x11\x45\x61\x73\x79\x20\x53\x74\x72\x65\x65\x74\x20\x44\x72\x61\x77",
    "Easy Street Draw diagram file",
    "Presentation"
  },
  .{
    "\x80\x00\x00\x20\x03\x12\x04",
    "Dreamcast audio",
    "Multimedia"
  },
  .{
    "\x81\x32\x84\xC1\x85\x05\xD0\x11",
    "Outlook Express address book (Win95)",
    "Email"
  },
  .{
    "\x4D\x53\x46\x54\x02\x00\x01\x00",
    "OLE-SPSS-Visual C++ library file",
    "Programming"
  },
  .{
    "\x7C",
    "Health Level-7 data (pipe delimited) file",
    "Programming"
  },
  .{
    "\x4D\x53\x5F\x56\x4F\x49\x43\x45",
    "Sony Compressed Voice File",
    "Multimedia"
  },
  .{
    "\x4D\x5A",
    "ActiveX-OLE Custom Control",
    "Windows"
  },
  .{
    "\x4D\x5A\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xFF\xFF",
    "ZoneAlam data file",
    "Miscellaneous"
  },
  .{
    "\x4D\x73\x52\x63\x66",
    "VMapSource GPS Waypoint Database",
    "Navigation"
  },
  .{
    "\x4E\x41\x56\x54\x52\x41\x46\x46",
    "TomTom traffic data",
    "Navigation"
  },
  .{
    "\x4E\x42\x2A\x00",
    "MS Windows journal",
    "Windows"
  },
  .{
    "\x4E\x49\x54\x46\x30",
    "National Imagery Transmission Format file",
    "Picture"
  },
  .{
    "\x4F\x7B",
    "Visio-DisplayWrite 4 text file",
    "Presentation"
  },
  .{
    "\x50\x00\x00\x00\x20\x00\x00\x00",
    "Quicken QuickFinder Information File",
    "Finance"
  },
  .{
    "\x50\x41\x47\x45\x44\x55",
    "Windows memory dump",
    "Windows"
  },
  .{
    "\x50\x41\x58",
    "PAX password protected bitmap",
    "Picture"
  },
  .{
    "\x50\x47\x50\x64\x4D\x41\x49\x4E",
    "PGP disk image",
    "Compressed archive"
  },
  .{
    "\x50\x4B\x03\x04",
    "PKZIP archive_1",
    "Compressed archive"
  },
  .{
    "\x50\x4B\x03\x04",
    "OpenDocument template",
    "Word processing suite"
  },
  .{
    "\x50\x4B\x03\x04\x0A\x00\x02\x00",
    "Open Publication Structure eBook",
    "Compressed archive"
  },
  .{
    "\x50\x4B\x05\x06",
    "PKZIP archive_2",
    "Compressed archive"
  },
  .{
    "\x50\x4B\x07\x08",
    "PKZIP archive_3",
    "Compressed archive"
  },
  .{
    "\x50\x4B\x4C\x49\x54\x45",
    "PKLITE archive",
    "Compressed archive"
  },
  .{
    "\x50\x55\x46\x58",
    "Puffer encrypted archive",
    "Encryption"
  },
  .{
    "\x52\x44\x58\x32\x0A",
    "R saved work space",
    "Programming"
  },
  .{
    "\x52\x45\x47\x45\x44\x49\x54",
    "WinNT Registry-Registry Undo files",
    "Windows"
  },
  .{
    "\x52\x49\x46\x46",
    "4X Movie video",
    "Multimedia"
  },
  .{
    "\x52\x4D\x49\x44\x64\x61\x74\x61",
    "RIFF Windows MIDI",
    "Multimedia"
  },
  .{
    "\x53\x43\x4D\x49",
    "Img Software Bitmap",
    "Picture"
  },
  .{
    "\x53\x48\x4F\x57",
    "Harvard Graphics presentation",
    "Presentation"
  },
  .{
    "\x53\x49\x45\x54\x52\x4F\x4E\x49",
    "Sietronics CPI XRD document",
    "Miscellaneous"
  },
  .{
    "\x53\x50\x46\x49\x00",
    "StorageCraft ShadownProtect backup file",
    "Backup"
  },
  .{
    "\x53\x50\x56\x42",
    "MultiBit Bitcoin blockchain file",
    "e-money"
  },
  .{
    "\x53\x51\x4C\x69\x74\x65\x20\x66\x6F\x72\x6D\x61\x74\x20\x33\x00",
    "SQLite database file",
    "Database"
  },
  .{
    "\x53\x5A\x20\x88\xF0\x27\x33\xD1",
    "QBASIC SZDD file",
    "Compressed archive"
  },
  .{
    "\x54\x48\x50\x00",
    "Wii-GameCube",
    "Multimedia"
  },
  .{
    "\x54\x68\x69\x73\x20\x69\x73\x20",
    "GNU Info Reader file",
    "Programming"
  },
  .{
    "\x55\x46\x4F\x4F\x72\x62\x69\x74",
    "UFO Capture map file",
    "Miscellaneous"
  },
  .{
    "\x57\x41\x56\x45\x66\x6D\x74\x20",
    "RIFF Windows Audio",
    "Multimedia"
  },
  .{
    "\x58\x50\x43\x4F\x4D\x0A\x54\x79",
    "XPCOM libraries",
    "Programming"
  },
  .{
    "\x5A\x57\x53",
    "Macromedia Shockwave Flash",
    "Multimedia"
  },
  .{
    "\x5B\x4D\x53\x56\x43",
    "Visual C++ Workbench Info File",
    "Programming"
  },
  .{
    "\x5B\x56\x4D\x44\x5D",
    "VocalTec VoIP media file",
    "Multimedia"
  },
  .{
    "\x5B\x57\x69\x6E\x64\x6F\x77\x73",
    "Microsoft Code Page Translation file",
    "Windows"
  },
  .{
    "\x5B\x70\x6C\x61\x79\x6C\x69\x73\x74\x5D",
    "WinAmp Playlist",
    "Audio"
  },
  .{
    "\x62\x65\x67\x69\x6E",
    "UUencoded file",
    "Compressed archive"
  },
  .{
    "\x62\x70\x6C\x69\x73\x74",
    "Binary property list (plist)",
    "System"
  },
  .{
    "\x63\x64\x73\x61\x65\x6E\x63\x72",
    "Macintosh encrypted Disk image (v1)",
    "Compressed archive"
  },
  .{
    "\x63\x75\x73\x68\x00\x00\x00\x02",
    "Photoshop Custom Shape",
    "Miscellaneous"
  },
  .{
    "\x64\x6E\x73\x2E",
    "Audacity audio file",
    "Multimedia"
  },
  .{
    "\x66\x49\x00\x00",
    "WinNT printer spool file",
    "Windows"
  },
  .{
    "\x66\x4C\x61\x43\x00\x00\x00\x22",
    "Free Lossless Audio Codec file",
    "Multimedia"
  },
  .{
    "\x66\x74\x79\x70\x71\x74\x20\x20",
    "QuickTime movie_7",
    "Multimedia"
  },
  .{
    "\x77\x69\x64\x65",
    "QuickTime movie_4",
    "Multimedia"
  },
  .{
    "\x73\x6B\x69\x70",
    "QuickTime movie_6",
    "Multimedia"
  },
  .{
    "\x73\x6D\x5F",
    "PalmOS SuperMemo",
    "Mobile"
  },
  .{
    "\x76\x32\x30\x30\x33\x2E\x31\x30",
    "Qimage filter",
    "Miscellaneous"
  },
  .{
    "\x7B\x22\x75\x72\x6C\x22\x3A\x20\x22\x68\x74\x74\x70\x73\x3A\x2F",
    "Google Drive Drawing link",
    "Word processing suite"
  },
  .{
    "\x80\x2A\x5F\xD7",
    "Kodak Cineon image",
    "Picture"
  },
  .{
    "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A",
    "PNG image",
    "Picture"
  },
  .{
    "\x00\x00\x00\x20\x66\x74\x79\x70\x68\x65\x69\x63",
    "High Efficiency Image Container (HEIC)_2",
    "Multimedia"
  },
  .{
    "\x00\x00\x00\x14\x66\x74\x79\x70",
    "3GPP multimedia files",
    "Multimedia"
  },
  .{
    "\x00\x00\x00\x14\x66\x74\x79\x70",
    "3rd Generation Partnership Project 3GPP",
    "Multimedia"
  },
  .{
    "\x00\x00\x01\xB3",
    "MPEG video file",
    "Multimedia"
  },
  .{
    "\x00\x00\x1A\x00\x00\x10\x04\x00",
    "Lotus 1-2-3 (v3)",
    "Spreadsheet"
  },
  .{
    "\x00\x00\x1A\x00\x02\x10\x04\x00",
    "Lotus 1-2-3 (v4-v5)",
    "Spreadsheet"
  },
  .{
    "\x00\x00\x1A\x00\x05\x10\x04",
    "Lotus 1-2-3 (v9)",
    "Spreadsheet"
  },
  .{
    "\x00\x00\x49\x49\x58\x50\x52",
    "Quark Express (Intel)",
    "Presentation"
  },
  .{
    "\x00\x00\x4D\x4D\x58\x50\x52",
    "Quark Express (Motorola)",
    "Presentation"
  },
  .{
    "\x00\x00\xFF\xFF\xFF\xFF",
    "Windows Help file_1",
    "Windows"
  },
  .{
    "\x00\x01\x00\x00\x53\x74\x61\x6E\x64\x61\x72\x64\x20\x41\x43\x45\x20\x44\x42",
    "Microsoft Access 2007",
    "Database"
  },
  .{
    "\x00\x01\x00\x00\x53\x74\x61\x6E\x64\x61\x72\x64\x20\x4A\x65\x74\x20\x44\x42",
    "Microsoft Access",
    "Database"
  },
  .{
    "\x00\x3B\x05\x00\x01\x00\x00\x00",
    "Paessler PRTG Monitoring System",
    "Database"
  },
  .{
    "\x01\x0F\x00\x00",
    "SQL Data Base",
    "Database"
  },
  .{
    "\x01\xDA\x01\x01\x00\x03",
    "Silicon Graphics RGB Bitmap",
    "Picture"
  },
  .{
    "\x03\x00\x00\x00",
    "Quicken price history",
    "Finance"
  },
  .{
    "\x07\x64\x74\x32\x64\x64\x74\x64",
    "DesignTools 2D Design file",
    "Miscellaneous"
  },
  .{
    "\x0C\xED",
    "Monochrome Picture TIFF bitmap",
    "Picture"
  },
  .{
    "\x0E\x4E\x65\x72\x6F\x49\x53\x4F",
    "Nero CD compilation",
    "Miscellaneous"
  },
  .{
    "\x0E\x57\x4B\x53",
    "DeskMate Worksheet",
    "Word processing suite"
  },
  .{
    "\x0F\x53\x49\x42\x45\x4C\x49\x55\x53",
    "Sibelius Music - Score",
    "Multimedia"
  },
  .{
    "\x1A\x02",
    "LH archive (old vers.-type 1)",
    "Compressed archive"
  },
  .{
    "\x1A\x08",
    "LH archive (old vers.-type 4)",
    "Compressed archive"
  },
  .{
    "\x1F\x8B\x08",
    "GZIP archive file",
    "Compressed archive"
  },
  .{
    "\x1F\x8B\x08\x00",
    "Synology router configuration backup file",
    "Network"
  },
  .{
    "\x21\x3C\x61\x72\x63\x68\x3E\x0A",
    "Unix archiver (ar)-MS Program Library Common Object File Format (COFF)",
    "Compressed archive"
  },
  .{
    "\x23\x20",
    "Cerius2 file",
    "Miscellaneous"
  },
  .{
    "\x23\x21\x41\x4D\x52",
    "Adaptive Multi-Rate ACELP Codec (GSM)",
    "Multimedia"
  },
  .{
    "\x23\x40\x7E\x5E",
    "VBScript Encoded script",
    "Programming"
  },
  .{
    "\x23\x50\x45\x53\x30",
    "Brother-Babylock-Bernina Home Embroidery",
    "Miscellaneous"
  },
  .{
    "\x2E\x72\x61\xFD\x00",
    "RealAudio streaming media",
    "Multimedia"
  },
  .{
    "\x30",
    "MS security catalog file",
    "Windows"
  },
  .{
    "\x30\x26\xB2\x75\x8E\x66\xCF\x11",
    "Windows Media Audio-Video File",
    "Multimedia"
  },
  .{
    "\x30\x37\x30\x37\x30",
    "cpio archive",
    "Compressed archive"
  },
  .{
    "\x32\x03\x10\x00\x00\x00\x00\x00\x00\x00\x80\x00\x00\x00\xFF\x00",
    "Pfaff Home Embroidery",
    "Miscellaneous"
  },
  .{
    "\x3C\x7E\x36\x3C\x5C\x25\x5F\x30\x67\x53\x71\x68\x3B",
    "BASE85 file",
    "Word processing"
  },
  .{
    "\x3E\x00\x03\x00\xFE\xFF\x09\x00\x06",
    "Quatro Pro for Windows 7.0",
    "Spreadsheet"
  },
  .{
    "\x41\x43\x31\x30",
    "Generic AutoCAD drawing",
    "Presentation"
  },
  .{
    "\x41\x43\x53\x44",
    "AOL parameter-info files",
    "Network"
  },
  .{
    "\x41\x4D\x59\x4F",
    "Harvard Graphics symbol graphic",
    "Presentation"
  },
  .{
    "\x41\x4F\x4C\x20\x46\x65\x65\x64",
    "AOL and AIM buddy list",
    "Network"
  },
  .{
    "\x41\x4F\x4C\x44\x42",
    "AOL user configuration",
    "Network"
  },
  .{
    "\x42\x4D",
    "Bitmap image",
    "Picture"
  },
  .{
    "\x43\x44\x44\x41\x66\x6D\x74\x20",
    "RIFF CD audio",
    "Multimedia"
  },
  .{
    "\x43\x4D\x4D\x4D\x15\x00\x00\x00",
    "Windows 7 thumbnail",
    "Windows"
  },
  .{
    "\x43\x61\x74\x61\x6C\x6F\x67\x20",
    "WhereIsIt Catalog",
    "Miscellaneous"
  },
  .{
    "\x43\x6C\x69\x65\x6E\x74\x20\x55",
    "IE History file",
    "Network"
  },
  .{
    "\x44\x41\x41\x00\x00\x00\x00\x00",
    "PowerISO Direct-Access-Archive image",
    "Compressed archive"
  },
  .{
    "\x44\x4D\x53\x21",
    "Amiga DiskMasher compressed archive",
    "Compressed archive"
  },
  .{
    "\x44\x56\x44",
    "DVR-Studio stream file",
    "Multimedia"
  },
  .{
    "\x45\x4C\x49\x54\x45\x20\x43\x6F",
    "Elite Plus Commander game file",
    "Miscellaneous"
  },
  .{
    "\x46\x49\x4C\x45",
    "NTFS MFT (FILE)",
    "Windows"
  },
  .{
    "\x46\x4F\x52\x4D",
    "EA Interchange Format File (IFF)_1",
    "Multimedia"
  },
  .{
    "\x47\x58\x32",
    "Show Partner graphics file",
    "Picture"
  },
  .{
    "\x47\x65\x6E\x65\x74\x65\x63\x20\x4F\x6D\x6E\x69\x63\x61\x73\x74",
    "Genetec video archive",
    "Multimedia"
  },
  .{
    "\x49\x20\x49",
    "TIFF file_1",
    "Picture"
  },
  .{
    "\x49\x49\x1A\x00\x00\x00\x48\x45",
    "Canon RAW file",
    "Picture"
  },
  .{
    "\x49\x49\x2A\x00",
    "TIFF file_2",
    "Picture"
  },
  .{
    "\x49\x54\x4F\x4C\x49\x54\x4C\x53",
    "MS Reader eBook",
    "Miscellaneous"
  },
  .{
    "\x4A\x47\x04\x0E",
    "AOL ART file_2",
    "Picture"
  },
  .{
    "\x4B\x49\x00\x00",
    "Win9x printer spool file",
    "Windows"
  },
  .{
    "\x4C\x41\x3A",
    "Tajima emboridery",
    "Miscellaneous"
  },
  .{
    "\x00\x00\x00",
    "High Efficiency Image Container (HEIC)_1",
    "Multimedia"
  },
  .{
    "\x00\x00\x00\x20\x66\x74\x79\x70",
    "3rd Generation Partnership Project 3GPP2",
    "Multimedia"
  },
  .{
    "\x00\x00\x02\x00",
    "Windows cursor",
    "Windows"
  },
  .{
    "\x00\x20\xAF\x30",
    "Wii images container",
    "System"
  },
  .{
    "\x00\x01\x00\x00\x00",
    "TrueType font file",
    "Windows"
  },
  .{
    "\x00\x01\x42\x41",
    "Palm Address Book Archive",
    "Mobile"
  },
  .{
    "\x00\x01\x42\x44",
    "Palm DateBook Archive",
    "Mobile"
  },
  .{
    "\x00\x1E\x84\x90\x00\x00\x00\x00",
    "Netscape Communicator (v4) mail folder",
    "Email"
  },
  .{
    "\x01\x01\x47\x19\xA4\x00\x00\x00\x00\x00\x00\x00",
    "The Bat! Message Base Index",
    "Email"
  },
  .{
    "\x01\x10",
    "Novell LANalyzer capture file",
    "Network"
  },
  .{
    "\x01\xFF\x02\x04\x03\x02",
    "Micrografx vector graphic file",
    "Picture"
  },
  .{
    "\x03\x00\x00\x00\x41\x50\x50\x52",
    "Approach index file",
    "Database"
  },
  .{
    "\x03\x64\x73\x73",
    "Digital Speech Standard (v3)",
    "Audio"
  },
  .{
    "\x05\x00\x00\x00",
    "INFO2 Windows recycle bin_2",
    "Windows"
  },
  .{
    "\x06\x06\xED\xF5\xD8\x1D\x46\xE5\xBD\x31\xEF\xE7\xFE\x74\xB7\x1D",
    "Adobe InDesign",
    "Media"
  },
  .{
    "\x06\x0E\x2B\x34\x02\x05\x01\x01\x0D\x01\x02\x01\x01\x02",
    "Material Exchange Format",
    "Media"
  },
  .{
    "\x09\x08\x10\x00\x00\x06\x05\x00",
    "Excel spreadsheet subheader_1",
    "Spreadsheet"
  },
  .{
    "\x0A\x05\x01\x01",
    "ZSOFT Paintbrush file_3",
    "Presentation"
  },
  .{
    "\x0A\x16\x6F\x72\x67\x2E\x62\x69\x74\x63\x6F\x69\x6E\x2E\x70\x72",
    "MultiBit Bitcoin wallet file",
    "e-money"
  },
  .{
    "\x0D\x44\x4F\x43",
    "DeskMate Document",
    "Word processing suite"
  },
  .{
    "\x10\x00\x00\x00",
    "Easy CD Creator 5 Layout file",
    "Utility"
  },
  .{
    "\x11\x00\x00\x00\x53\x43\x43\x41",
    "Windows prefetch file",
    "Windows"
  },
  .{
    "\x1A\x35\x01\x00",
    "WinPharoah capture file",
    "Network"
  },
  .{
    "\x1A\x45\xDF\xA3",
    "WebM video file",
    "Multimedia"
  },
  .{
    "\x1A\x45\xDF\xA3",
    "Matroska stream file_1",
    "Multimedia"
  },
  .{
    "\x1D\x7D",
    "WordStar Version 5.0-6.0 document",
    "Word processing suite"
  },
  .{
    "\x1F\x9D\x90",
    "Compressed tape archive_1",
    "Compressed archive"
  },
  .{
    "\x21",
    "MapInfo Sea Chart",
    "Navigation"
  },
  .{
    "\x21\x0D\x0A\x43\x52\x52\x2F\x54\x68\x69\x73\x20\x65\x6C\x65\x63",
    "NOAA Raster Navigation Chart (RNC) file",
    "Navigation"
  },
  .{
    "\x23\x3F\x52\x41\x44\x49\x41\x4E",
    "Radiance High Dynamic Range image file",
    "Picture"
  },
  .{
    "\x28\x54\x68\x69\x73\x20\x66\x69",
    "BinHex 4 Compressed Archive",
    "Compressed archive"
  },
  .{
    "\x2E\x52\x45\x43",
    "RealPlayer video file (V11+)",
    "Multimedia"
  },
  .{
    "\x2F\x2F\x20\x3C\x21\x2D\x2D\x20\x3C\x6D\x64\x62\x3A\x6D\x6F\x72\x6B\x3A\x7A",
    "Thunderbird-Mozilla Mail Summary File",
    "E-mail"
  },
  .{
    "\x30\x20\x48\x45\x41\x44",
    "GEnealogical Data COMmunication (GEDCOM) file",
    "Miscellaneous"
  },
  .{
    "\x30\x31\x4F\x52\x44\x4E\x41\x4E",
    "National Transfer Format Map",
    "Miscellaneous"
  },
  .{
    "\x32\xBE",
    "MS Write file_2",
    "Word processing suite"
  },
  .{
    "\x3C",
    "BizTalk XML-Data Reduced Schema",
    "Miscellaneous"
  },
  .{
    "\x3C\x3F",
    "Windows Script Component",
    "Windows"
  },
  .{
    "\x3C\x3F\x78\x6D\x6C\x20\x76\x65\x72\x73\x69\x6F\x6E\x3D\x22\x31\x2E\x30\x22\x3F\x3E\x0D\x0A\x3C\x4D\x4D\x43\x5F\x43\x6F\x6E\x73\x6F\x6C\x65\x46\x69\x6C\x65\x20\x43\x6F\x6E\x73\x6F\x6C\x65\x56\x65\x72\x73\x69\x6F\x6E\x3D\x22",
    "MMC Snap-in Control file",
    "Windows"
  },
  .{
    "\x3C\x4B\x65\x79\x68\x6F\x6C\x65\x3E",
    "Google Earth Keyhole Overlay file",
    "Navigation"
  },
  .{
    "\x40\x40\x40\x20\x00\x00\x40\x40\x40\x40",
    "EndNote Library File",
    "Miscellaneous"
  },
  .{
    "\x41\x4F\x4C",
    "AOL config files",
    "Network"
  },
  .{
    "\x41\x4F\x4C\x49\x4E\x44\x45\x58",
    "AOL address book index",
    "Network"
  },
  .{
    "\x42\x41\x41\x44",
    "NTFS MFT (BAAD)",
    "Windows"
  },
  .{
    "\x42\x44\x69\x63",
    "Google Chrome dictionary file",
    "System"
  },
  .{
    "\x42\x4C\x49\x32\x32\x33",
    "Speedtouch router firmware",
    "Network"
  },
  .{
    "\x42\x50\x47\xFB",
    "Better Portable Graphics",
    "Multimedia"
  },
  .{
    "\x42\x65\x67\x69\x6E\x20\x50\x75\x66\x66\x65\x72",
    "Puffer ASCII encrypted archive",
    "Encryption"
  },
  .{
    "\x43\x23\x2B\x44\xA4\x43\x4D\xA5",
    "RagTime document",
    "Word processing suite"
  },
  .{
    "\x43\x4D\x58\x31",
    "Corel Binary metafile",
    "Miscellaneous"
  },
  .{
    "\x43\x50\x54\x46\x49\x4C\x45",
    "Corel Photopaint file_2",
    "Presentation"
  },
  .{
    "\x43\x52\x55\x53\x48\x20\x76",
    "Crush compressed archive",
    "Compressed archive"
  },
  .{
    "\x43\x72\x32\x34",
    "Google Chrome Extension",
    "Programming"
  },
  .{
    "\x43\x72\x4F\x44",
    "Google Chromium patch update",
    "System"
  },
  .{
    "\x43\x72\x65\x61\x74\x69\x76\x65\x20\x56\x6F\x69\x63\x65\x20\x46",
    "Creative Voice",
    "Multimedia"
  },
  .{
    "\x44\x41\x58\x00",
    "DAX Compressed CD image",
    "Miscellaneous"
  },
  .{
    "\x45\x56\x46\x09\x0D\x0A\xFF\x00",
    "Expert Witness Compression Format",
    "Miscellaneous"
  },
  .{
    "\x45\x6C\x66\x46\x69\x6C\x65\x00",
    "Windows Vista event log",
    "Windows"
  },
  .{
    "\x46\x41\x58\x43\x4F\x56\x45\x52",
    "MS Fax Cover Sheet",
    "Miscellaneous"
  },
  .{
    "\x46\x44\x42\x48\x00",
    "Fiasco database definition file",
    "Database"
  },
  .{
    "\x46\x72\x6F\x6D",
    "Generic e-mail_2",
    "Email"
  },
  .{
    "\x48\x48\x47\x42\x31",
    "Harvard Graphics presentation file",
    "Presentation"
  },
  .{
    "\x49\x54\x53\x46",
    "MS Compiled HTML Help File",
    "Windows"
  },
  .{
    "\x4D\x41\x72\x30\x00",
    "MAr compressed archive",
    "Compressed archive"
  },
  .{
    "\x4D\x49\x4C\x45\x53",
    "Milestones project management file",
    "Miscellaneous"
  },
  .{
    "\x4D\x4D\x00\x2A",
    "TIFF file_3",
    "Picture"
  },
  .{
    "\x4D\x52\x56\x4E",
    "VMware BIOS state file",
    "Miscellaneous"
  },
  .{
    "\x4D\x54\x68\x64",
    "Yamaha Piano",
    "Multimedia"
  },
  .{
    "\x4D\x56\x32\x43",
    "Milestones project management file_2",
    "Miscellaneous"
  },
  .{
    "\x4D\x5A",
    "Library cache file",
    "Windows"
  },
  .{
    "\x4D\x5A",
    "Font file",
    "Windows"
  },
  .{
    "\x4D\x5A",
    "VisualBASIC application",
    "Programming"
  },
  .{
    "\x4D\x5A",
    "Windows virtual device drivers",
    "Windows"
  },
  .{
    "\x4D\x5A\x90\x00\x03\x00\x00\x00",
    "Audition graphic filter",
    "Miscellaneous"
  },
  .{
    "\x4D\x69\x63\x72\x6F\x73\x6F\x66\x74\x20\x43\x2F\x43\x2B\x2B\x20",
    "MS C++ debugging symbols file",
    "Programming"
  },
  .{
    "\x4D\x69\x63\x72\x6F\x73\x6F\x66\x74\x20\x56\x69\x73\x75\x61\x6C",
    "Visual Studio .NET file",
    "Programming"
  },
  .{
    "\x4E\x61\x6D\x65\x3A\x20",
    "Agent newsreader character map",
    "Miscellaneous"
  },
  .{
    "\x4F\x50\x43\x4C\x44\x41\x54",
    "1Password 4 Cloud Keychain",
    "Encryption"
  },
  .{
    "\x4F\x50\x4C\x44\x61\x74\x61\x62",
    "Psion Series 3 Database",
    "Database"
  },
  .{
    "\x4F\x54\x54\x4F\x00",
    "OpenType font",
    "Word processing suite"
  },
  .{
    "\x50\x49\x43\x54\x00\x08",
    "ChromaGraph Graphics Card Bitmap",
    "Picture"
  },
  .{
    "\x50\x4B\x03\x04",
    "MS Office Open XML Format Document",
    "Word processing suite"
  },
  .{
    "\x50\x4B\x03\x04",
    "Java archive_1",
    "Programming"
  },
  .{
    "\x50\x4B\x03\x04",
    "Google Earth session file",
    "Navigation"
  },
  .{
    "\x50\x4B\x03\x04",
    "Microsoft Open XML paper specification",
    "Word processing suite"
  },
  .{
    "\x50\x4B\x03\x04",
    "OpenOffice documents",
    "Word processing suite"
  },
  .{
    "\x50\x4B\x03\x04",
    "XML paper specification file",
    "Word processing suite"
  },
  .{
    "\x50\x4B\x03\x04\x14\x00\x08\x00",
    "Java archive_2",
    "Programming"
  },
  .{
    "\x50\x4D\x43\x43",
    "Windows Program Manager group file",
    "Windows"
  },
  .{
    "\x50\x4E\x43\x49\x55\x4E\x44\x4F",
    "Norton Disk Doctor undo file",
    "Miscellaneous"
  },
  .{
    "\x51\x57\x20\x56\x65\x72\x2E\x20",
    "Quicken data file",
    "Finance"
  },
  .{
    "\x52\x41\x5A\x41\x54\x44\x42\x31",
    "Shareaza (P2P) thumbnail",
    "Network"
  },
  .{
    "\x52\x45\x56\x4E\x55\x4D\x3A\x2C",
    "Antenna data file",
    "Miscellaneous"
  },
  .{
    "\x52\x49\x46\x46",
    "Corel Presentation Exchange metadata",
    "Presentation"
  },
  .{
    "\x52\x54\x53\x53",
    "WinNT Netmon capture file",
    "Network"
  },
  .{
    "\x52\x61\x72\x21\x1A\x07\x00",
    "WinRAR compressed archive",
    "Compressed archive"
  },
  .{
    "\x52\x65\x74\x75\x72\x6E\x2D\x50",
    "Generic e-mail_1",
    "Email"
  },
  .{
    "\x53\x49\x4D\x50\x4C\x45\x20\x20\x3D\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x54",
    "Flexible Image Transport System (FITS) file",
    "multimedia"
  },
  .{
    "\x53\x4D\x41\x52\x54\x44\x52\x57",
    "SmartDraw Drawing file",
    "Presentation"
  },
  .{
    "\x53\x74\x75\x66\x66\x49\x74\x20",
    "StuffIt compressed archive",
    "Compressed archive"
  },
  .{
    "\x53\x75\x70\x65\x72\x43\x61\x6C",
    "SuperCalc worksheet",
    "Spreadsheet"
  },
  .{
    "\x55\x43\x45\x58",
    "Unicode extensions",
    "Windows"
  },
  .{
    "\x55\x46\x41\xC6\xD2\xC1",
    "UFA compressed archive",
    "Compressed archive"
  },
  .{
    "\x55\x6E\x46\x69\x6E\x4D\x46",
    "Measurement Data Format file",
    "Miscellaneous"
  },
  .{
    "\x56\x43\x50\x43\x48\x30",
    "Visual C PreCompiled header",
    "Programming"
  },
  .{
    "\x57\x6F\x72\x64\x50\x72\x6F",
    "Lotus WordPro file",
    "Word processing suite"
  },
  .{
    "\x58\x2D",
    "Exchange e-mail",
    "Email"
  },
  .{
    "\x58\x43\x50\x00",
    "Packet sniffer files",
    "Network"
  },
  .{
    "\x5F\x27\xA8\x89",
    "Jar archive",
    "Miscellaneous"
  },
  .{
    "\x63\x6F\x6E\x65\x63\x74\x69\x78",
    "Virtual PC HD image",
    "Miscellaneous"
  },
  .{
    "\x64\x65\x78\x0A",
    "Dalvik (Android) executable file",
    "Mobile"
  },
  .{
    "\x65\x6E\x63\x72\x63\x64\x73\x61",
    "Macintosh encrypted Disk image (v2)",
    "Compressed archive"
  },
  .{
    "\x66\x74\x79\x70\x4D\x53\x4E\x56",
    "MPEG-4 video file_2",
    "Multimedia"
  },
  .{
    "\x66\x74\x79\x70\x6D\x70\x34\x32",
    "MPEG-4 video-QuickTime file",
    "Multimedia"
  },
  .{
    "\x69\x63\x6E\x73",
    "MacOS icon file",
    "System"
  },
  .{
    "\x6C\x33\x33\x6C",
    "Skype user data file",
    "Network"
  },
  .{
    "\x6D\x64\x61\x74",
    "QuickTime movie_3",
    "Multimedia"
  },
  .{
    "\x6D\x73\x46\x69\x6C\x74\x65\x72\x4C\x69\x73\x74",
    "Internet Explorer v11 Tracking Protection List",
    "Programming"
  },
  .{
    "\x6F\x3C",
    "SMS text (SIM)",
    "Mobile"
  },
  .{
    "\x72\x65\x67\x66",
    "WinNT registry file",
    "Windows"
  },
  .{
    "\x76\x2F\x31\x01",
    "OpenEXR bitmap image",
    "Picture"
  },
  .{
    "\x77\x4F\x46\x32",
    "Web Open Font Format 2",
    "Open font"
  },
  .{
    "\x7A\x62\x65\x78",
    "ZoomBrowser Image Index",
    "Miscellaneous"
  },
  .{
    "\x7B\x0D\x0A\x6F\x20",
    "Windows application log",
    "Windows"
  },
  .{
    "\x7B\x5C\x70\x77\x69",
    "MS WinMobile personal note",
    "Mobile"
  },
  .{
    "\x7E\x42\x4B\x00",
    "Corel Paint Shop Pro image",
    "Presentation"
  },
  .{
    "\x7E\x74\x2C\x01\x50\x70\x02\x4D\x52",
    "Digital Watchdog DW-TP-500G audio",
    "Audio"
  },
  .{
    "\x4C\x49\x53\x54",
    "EA Interchange Format File (IFF)_2",
    "Multimedia"
  },
  .{
    "\x4C\x56\x46\x09\x0D\x0A\xFF\x00",
    "Logical File Evidence Format",
    "Miscellaneous"
  },
  .{
    "\x4D\x41\x52\x31\x00",
    "Mozilla archive",
    "Network"
  },
  .{
    "\x4D\x43\x57\x20\x54\x65\x63\x68\x6E\x6F\x67\x6F\x6C\x69\x65\x73",
    "TargetExpress target file",
    "Miscellaneous"
  },
  .{
    "\x4D\x44\x4D\x50\x93\xA7",
    "Windows dump file",
    "Windows"
  },
  .{
    "\x4D\x4C\x53\x57",
    "Skype localization data file",
    "Network"
  },
  .{
    "\x4D\x4D\x00\x2B",
    "TIFF file_4",
    "Picture"
  },
  .{
    "\x4D\x53\x43\x46",
    "Microsoft cabinet file",
    "Windows"
  },
  .{
    "\x4D\x54\x68\x64",
    "MIDI sound file",
    "Multimedia"
  },
  .{
    "\x4D\x56",
    "CD Stomper Pro label file",
    "Miscellaneous"
  },
  .{
    "\x4D\x5A",
    "Windows-DOS executable file",
    "Windows"
  },
  .{
    "\x4D\x5A",
    "MS audio compression manager driver",
    "Multimedia"
  },
  .{
    "\x4D\x5A",
    "Control panel application",
    "Windows"
  },
  .{
    "\x4D\x5A\x90\x00\x03\x00\x00\x00",
    "Acrobat plug-in",
    "Word processing suite"
  },
  .{
    "\x4E\x45\x53\x4D\x1A\x01",
    "NES Sound file",
    "Multimedia"
  },
  .{
    "\x4F\x67\x67\x53\x00\x02\x00\x00",
    "Ogg Vorbis Codec compressed file",
    "Multimedia"
  },
  .{
    "\x50\x35\x0A",
    "Portable Graymap Graphic",
    "Picture"
  },
  .{
    "\x50\x41\x43\x4B",
    "Quake archive file",
    "Compressed archive"
  },
  .{
    "\x50\x45\x53\x54",
    "PestPatrol data-scan strings",
    "Miscellaneous"
  },
  .{
    "\x50\x4B\x03\x04",
    "Android package",
    "Mobile"
  },
  .{
    "\x50\x4B\x03\x04",
    "MacOS X Dashboard Widget",
    "MacOS"
  },
  .{
    "\x50\x4B\x03\x04",
    "KWord document",
    "Word processing suite"
  },
  .{
    "\x50\x4B\x03\x04",
    "Windows Media compressed skin file",
    "Windows"
  },
  .{
    "\x50\x4B\x03\x04\x14\x00\x01\x00",
    "ZLock Pro encrypted ZIP",
    "Compressed archive"
  },
  .{
    "\x50\x4B\x03\x04\x14\x00\x06\x00",
    "MS Office 2007 documents",
    "Word processing suite"
  },
  .{
    "\x50\x4B\x53\x70\x58",
    "PKSFX self-extracting archive",
    "Compressed archive"
  },
  .{
    "\x50\x4D\x4F\x43\x43\x4D\x4F\x43",
    "Microsoft Windows User State Migration Tool",
    "Windows"
  },
  .{
    "\x51\x45\x4C\x20",
    "Quicken data",
    "Finance"
  },
  .{
    "\x52\x00\x6F\x00\x6F\x00\x74\x00\x20\x00\x45\x00\x6E\x00\x74\x00\x72\x00\x79\x00",
    "Outlook-Exchange message subheader",
    "Email"
  },
  .{
    "\x52\x49\x46\x46",
    "Video CD MPEG movie",
    "Multimedia"
  },
  .{
    "\x52\x49\x46\x46",
    "Micrografx Designer graphic",
    "Picture"
  },
  .{
    "\x53\x43\x43\x41",
    "Windows prefetch",
    "Windows"
  },
  .{
    "\x53\x44\x50\x58",
    "SMPTE DPX (big endian)",
    "Picture"
  },
  .{
    "\x53\x51\x4C\x4F\x43\x4F\x4E\x56",
    "DB2 conversion file",
    "Database"
  },
  .{
    "\x53\x5A\x44\x44\x88\xF0\x27\x33",
    "SZDD file format",
    "Compressed archive"
  },
  .{
    "\x57\x4D\x4D\x50",
    "Walkman MP3 file",
    "Multimedia"
  },
  .{
    "\x57\x53\x32\x30\x30\x30",
    "WordStar for Windows file",
    "Word processing suite"
  },
  .{
    "\x57\x69\x6E\x5A\x69\x70",
    "WinZip compressed archive",
    "Compressed archive"
  },
  .{
    "\x5B\x47\x65\x6E\x65\x72\x61\x6C",
    "MS Exchange configuration file",
    "Email"
  },
  .{
    "\x5B\x50\x68\x6F\x6E\x65\x5D",
    "Dial-up networking file",
    "Network"
  },
  .{
    "\x5B\x56\x45\x52\x5D",
    "Lotus AMI Pro document_1",
    "Word processing suite"
  },
  .{
    "\x5D\xFC\xC8\x00",
    "Husqvarna Designer",
    "Miscellaneous"
  },
  .{
    "\x5F\x43\x41\x53\x45\x5F",
    "EnCase case file",
    "Miscellaneous"
  },
  .{
    "\x60\xEA",
    "Compressed archive file",
    "Compressed archive"
  },
  .{
    "\x62\x65\x67\x69\x6E\x2D\x62\x61\x73\x65\x36\x34",
    "UUencoded BASE64 file",
    "Compressed archive"
  },
  .{
    "\x63\x61\x66\x66",
    "Apple Core Audio File",
    "Multimedia"
  },
  .{
    "\x64\x38\x3A\x61\x6E\x6E\x6F\x75\x6E\x63\x65",
    "Torrent file",
    "Compressed archive"
  },
  .{
    "\x66\x74\x79\x70\x33\x67\x70\x35",
    "MPEG-4 video file_1",
    "Multimedia"
  },
  .{
    "\x66\x74\x79\x70\x4D\x34\x41\x20",
    "Apple Lossless Audio Codec file",
    "Multimedia"
  },
  .{
    "\x67\x69\x6d\x70\x20\x78\x63\x66",
    "GIMP file",
    "Picture"
  },
  .{
    "\x68\x49\x00\x00",
    "Win Server 2003 printer spool file",
    "Windows"
  },
  .{
    "\x6D\x75\x6C\x74\x69\x42\x69\x74\x2E\x69\x6E\x66\x6F",
    "MultiBit Bitcoin wallet information",
    "E-money"
  },
  .{
    "\x6F\x70\x64\x61\x74\x61\x30\x31",
    "1Password 4 Cloud Keychain encrypted data",
    "Encryption"
  },
  .{
    "\x73\x6C\x68\x21",
    "Allegro Generic Packfile (compressed)",
    "Miscellaneous"
  },
  .{
    "\x73\x6F\x6C\x69\x64",
    "STL (STereoLithography) file",
    "Multimedia"
  },
  .{
    "\x73\x72\x63\x64\x6F\x63\x69\x64",
    "CALS raster bitmap",
    "Picture"
  },
  .{
    "\x75\x73\x74\x61\x72",
    "Tape Archive",
    "Compressed archive"
  },
  .{
    "\x77\x4F\x46\x46",
    "Web Open Font Format",
    "Open font"
  },
  .{
    "\x78\x61\x72\x21",
    "eXtensible ARchive file",
    "Compressed archive"
  },
  .{
    "\x7B\x5C\x72\x74\x66\x31",
    "Rich Text Format",
    "Word processing suite"
  },
  .{
    "\x7F\x45\x4C\x46",
    "ELF executable",
    "Linux-Unix"
  },
  .{
    "\x81\xCD\xAB",
    "WordPerfect text",
    "Word processing suite"
  },
  .{
    "\x80",
    "Relocatable object code",
    "Windows"
  },
  .{
    "\x8A\x01\x09\x00\x00\x00\xE1\x08",
    "MS Answer Wizard",
    "Windows"
  },
  .{
    "\xA1\xB2\xC3\xD4",
    "tcpdump (libpcap) capture file",
    "Network"
  },
  .{
    "\xA1\xB2\xCD\x34",
    "Extended tcpdump (libpcap) capture file",
    "Network"
  },
  .{
    "\xAC\x9E\xBD\x8F\x00\x00",
    "Quicken data",
    "Finance"
  },
  .{
    "\xC8\x00\x79\x00",
    "Jeppesen FliteLog file",
    "Miscellaneous"
  },
  .{
    "\xCE\x24\xB9\xA2\x20\x00\x00\x00",
    "Acronis True Image_2",
    "Multimedia"
  },
  .{
    "\xCF\xFA\xED\xFE",
    "OS X ABI Mach-O binary (64-bit reverse)",
    "Programming"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Visual Studio Solution User Options file",
    "Programming"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "SPSS output file",
    "Miscellaneous"
  },
  .{
    "\xD2\x0A\x00\x00",
    "WinPharoah filter file",
    "Network"
  },
  .{
    "\xE4\x52\x5C\x7B\x8C\xD8\xA7\x4D",
    "MS OneNote note",
    "Miscellaneous"
  },
  .{
    "\xEB",
    "Windows executable file_3",
    "Windows"
  },
  .{
    "\xEB\x3C\x90\x2A",
    "GEM Raster file",
    "Picture"
  },
  .{
    "\xEB\x52\x90\x2D\x46\x56\x45\x2D",
    "BitLocker boot sector (Vista)",
    "Windows"
  },
  .{
    "\xEB\x58\x90\x2D\x46\x56\x45\x2D",
    "BitLocker boot sector (Win7)",
    "Windows"
  },
  .{
    "\xED\xAB\xEE\xDB",
    "RedHat Package Manager",
    "Compressed archive"
  },
  .{
    "\xF8\xFF\xFF\x0F\xFF\xFF\xFF\x0F",
    "FAT32 File Allocation Table_1",
    "Windows"
  },
  .{
    "\xF8\xFF\xFF\x0F\xFF\xFF\xFF\xFF",
    "FAT32 File Allocation Table_2",
    "Windows"
  },
  .{
    "\xFD\xFF\xFF\xFF",
    "Thumbs.db subheader",
    "Windows"
  },
  .{
    "\xFD\xFF\xFF\xFF\x23",
    "Excel spreadsheet subheader_5",
    "Spreadsheet"
  },
  .{
    "\xFE\xED\xFE\xED",
    "JavaKeyStore",
    "Programming"
  },
  .{
    "\xFF\xF1",
    "MPEG-4 AAC audio",
    "Audio"
  },
  .{
    "\x99\x01",
    "PGP public keyring",
    "Miscellaneous"
  },
  .{
    "\x9C\xCB\xCB\x8D\x13\x75\xD2\x11",
    "Outlook address file",
    "Email"
  },
  .{
    "\xA9\x0D\x00\x00\x00\x00\x00\x00",
    "Access Data FTK evidence",
    "Miscellaneous"
  },
  .{
    "\xAB\x4B\x54\x58\x20\x31\x31\xBB\x0D\x0A\x1A\x0A",
    "Khronos texture file",
    "Picture"
  },
  .{
    "\xAC\xED",
    "Java serialization data",
    "Programming"
  },
  .{
    "\xB1\x68\xDE\x3A",
    "PCX bitmap",
    "Presentation"
  },
  .{
    "\xB4\x6E\x68\x44",
    "Acronis True Image_1",
    "Miscellaneous"
  },
  .{
    "\xB5\xA2\xB0\xB3\xB3\xB0\xA5\xB5",
    "Windows calendar",
    "Windows"
  },
  .{
    "\xC3\xAB\xCD\xAB",
    "MS Agent Character file",
    "Windows"
  },
  .{
    "\xCF\xAD\x12\xFE",
    "Outlook Express e-mail folder",
    "Email"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Lotus-IBM Approach 97 file",
    "Database"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "MSWorks database file",
    "Database"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Microsoft Common Console Document",
    "Windows"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Microsoft Installer package",
    "Windows"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "ArcMap GIS project file",
    "Miscellaneous"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Developer Studio File Options file",
    "Programming"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "MS Publisher file",
    "Word processing suite"
  },
  .{
    "\xDB\xA5\x2D\x00",
    "Word 2.0 file",
    "Word processing"
  },
  .{
    "\xDC\xFE",
    "eFax file",
    "Miscellaneous"
  },
  .{
    "\xE3\x82\x85\x96",
    "Win98 password file",
    "Windows"
  },
  .{
    "\xE8",
    "Windows executable file_1",
    "Windows"
  },
  .{
    "\xF9\xBE\xB4\xD9",
    "Bitcoin-Qt blockchain block file",
    "E-money"
  },
  .{
    "\xFD\x37\x7A\x58\x5A\x00",
    "MS Publisher subheader",
    "Word processing"
  },
  .{
    "\xFD\xFF\xFF\xFF\x02",
    "MS Publisher file subheader",
    "Word processing suite"
  },
  .{
    "\xFD\xFF\xFF\xFF\x04",
    "QuickBooks Portable Company File",
    "Financial"
  },
  .{
    "\xFD\xFF\xFF\xFF\x22",
    "Excel spreadsheet subheader_4",
    "Spreadsheet"
  },
  .{
    "\xFE\xED\xFA\xCE",
    "OS X ABI Mach-O binary (32-bit)",
    "Programming"
  },
  .{
    "\xFE\xED\xFA\xCF",
    "OS X ABI Mach-O binary (64-bit)",
    "Programming"
  },
  .{
    "\xFE\xFF",
    "UTF-16-UCS-2 file",
    "Windows"
  },
  .{
    "\xFF\x00\x02\x00\x04\x04\x05\x54",
    "Works for Windows spreadsheet",
    "Spreadsheet"
  },
  .{
    "\xFF\x0A\x00",
    "QuickReport Report",
    "Financial"
  },
  .{
    "\xFF\x57\x50\x43",
    "WordPerfect text and graphics",
    "Word processing suite"
  },
  .{
    "\xFF\xD8\xFF",
    "JPEG-EXIF-SPIFF images",
    "Picture"
  },
  .{
    "\xFF\xF9",
    "MPEG-2 AAC audio",
    "Audio"
  },
  .{
    "\x95\x01",
    "PGP secret keyring_2",
    "Miscellaneous"
  },
  .{
    "\x97\x4A\x42\x32\x0D\x0A\x1A\x0A",
    "JBOG2 image file",
    "Picture"
  },
  .{
    "\xA0\x46\x1D\xF0",
    "PowerPoint presentation subheader_3",
    "Presentation"
  },
  .{
    "\xAC\xED\x00\x05\x73\x72\x00\x12",
    "BGBlitz position database file",
    "Miscellaneous"
  },
  .{
    "\xB0\x4D\x46\x43",
    "Win95 password file",
    "Windows"
  },
  .{
    "\xBE\xBA\xFE\xCA\x0F\x50\x61\x6C\x6D\x53\x47\x20\x44\x61\x74\x61",
    "Palm Desktop DateBook",
    "Mobile"
  },
  .{
    "\xCC\x52\x33\xFC\xE9\x2C\x18\x48\xAF\xE3\x36\x30\x1A\x39\x40\x06",
    "Nokia phone backup file",
    "Mobile"
  },
  .{
    "\xCD\x20\xAA\xAA\x02\x00\x00\x00",
    "NAV quarantined virus file",
    "Miscellaneous"
  },
  .{
    "\xCE\xFA\xED\xFE",
    "OS X ABI Mach-O binary (32-bit reverse)",
    "Programming"
  },
  .{
    "\xCF\x11\xE0\xA1\xB1\x1A\xE1\x00",
    "Perfect Office document",
    "Word processing suite"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "CaseWare Working Papers",
    "Miscellaneous"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Microsoft Installer Patch",
    "Windows"
  },
  .{
    "\xD4\x2A",
    "AOL history|typed URL files",
    "Network"
  },
  .{
    "\xD7\xCD\xC6\x9A",
    "Windows graphics metafile",
    "Windows"
  },
  .{
    "\xEC\xA5\xC1\x00",
    "Word document subheader",
    "Word processing suite"
  },
  .{
    "\xEF\xBB\xBF\x3C\x3F",
    "Windows Script Component (UTF-8)_2",
    "Windows"
  },
  .{
    "\xEF\xBB\xBF\x3C\x3F\x78\x6D\x6C\x20\x76\x65\x72\x73\x69\x6F\x6E",
    "YouTube Timed Text (subtitle) file",
    "Video"
  },
  .{
    "\xF0\xFF\xFF",
    "FAT12 File Allocation Table",
    "Windows"
  },
  .{
    "\xF8\xFF\xFF\xFF",
    "FAT16 File Allocation Table",
    "Windows"
  },
  .{
    "\xFD\x37\x7A\x58\x5A\x00",
    "XZ archive",
    "Compressed archive"
  },
  .{
    "\xFD\xFF\xFF\xFF\x0E\x00\x00\x00",
    "PowerPoint presentation subheader_4",
    "Presentation"
  },
  .{
    "\xFD\xFF\xFF\xFF\x1F",
    "Excel spreadsheet subheader_3",
    "Spreadsheet"
  },
  .{
    "\xFD\xFF\xFF\xFF\x20",
    "Developer Studio subheader",
    "Programming"
  },
  .{
    "\xFD\xFF\xFF\xFF\x28",
    "Excel spreadsheet subheader_6",
    "Spreadsheet"
  },
  .{
    "\xFF\x4B\x45\x59\x42\x20\x20\x20",
    "Keyboard driver file",
    "Windows"
  },
  .{
    "\xFF\xD8",
    "Generic JPEG Image file",
    "Picture"
  },
  .{
    "\xFF\xFE",
    "UTF-32-UCS-2 file",
    "Windows"
  },
  .{
    "\xFF\xFE\x00\x00",
    "UTF-32-UCS-4 file",
    "Windows"
  },
  .{
    "\xFF\xFE\x23\x00\x6C\x00\x69\x00",
    "MSinfo file",
    "Windows"
  },
  .{
    "\x91\x33\x48\x46",
    "Hamarsoft compressed archive",
    "Compressed archive"
  },
  .{
    "\x95\x00",
    "PGP secret keyring_1",
    "Miscellaneous"
  },
  .{
    "\x99",
    "GPG public keyring",
    "Miscellaneous"
  },
  .{
    "\xB8\xC9\x0C\x00",
    "InstallShield Script",
    "Windows"
  },
  .{
    "\xBE\x00\x00\x00\xAB",
    "MS Write file_3",
    "Word processing suite"
  },
  .{
    "\xC5\xD0\xD3\xC6",
    "Adobe encapsulated PostScript",
    "Word processing suite"
  },
  .{
    "\xCA\xFE\xBA\xBE",
    "Java bytecode",
    "Programming"
  },
  .{
    "\xCE\xCE\xCE\xCE",
    "Java Cryptography Extension keystore",
    "Encryption"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Microsoft Office document",
    "Word processing suite"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Access project file",
    "Database"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Minitab data file",
    "Statistics"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Revit Project file",
    "Miscellaneous"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "Visio file",
    "Miscellaneous"
  },
  .{
    "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1",
    "MSWorks text document",
    "Word processing suite"
  },
  .{
    "\xD4\xC3\xB2\xA1",
    "WinDump (winpcap) capture file",
    "Network"
  },
  .{
    "\xDC\xDC",
    "Corel color palette",
    "Presentation"
  },
  .{
    "\xE3\x10\x00\x01\x00\x00\x00\x00",
    "Amiga icon",
    "Miscellaneous"
  },
  .{
    "\xE9",
    "Windows executable file_2",
    "Windows"
  },
  .{
    "\xEF\xBB\xBF",
    "UTF-8 file",
    "Windows"
  },
  .{
    "\xEF\xBB\xBF\x3C",
    "Windows Script Component (UTF-8)_1",
    "Windows"
  },
  .{
    "\xFD\xFF\xFF\xFF\x04",
    "Microsoft Outlook-Exchange Message",
    "Email"
  },
  .{
    "\xFD\xFF\xFF\xFF\x04",
    "Visual Studio Solution subheader",
    "Programming"
  },
  .{
    "\xFD\xFF\xFF\xFF\x10",
    "Excel spreadsheet subheader_2",
    "Spreadsheet"
  },
  .{
    "\xFD\xFF\xFF\xFF\x1C\x00\x00\x00",
    "PowerPoint presentation subheader_5",
    "Presentation"
  },
  .{
    "\xFD\xFF\xFF\xFF\x29",
    "Excel spreadsheet subheader_7",
    "Spreadsheet"
  },
  .{
    "\xFD\xFF\xFF\xFF\x43\x00\x00\x00",
    "PowerPoint presentation subheader_6",
    "Presentation"
  },
  .{
    "\xFE\xEF",
    "Symantex Ghost image file",
    "Compressed archive"
  },
  .{
    "\xFF",
    "Windows executable",
    "Windows"
  },
  .{
    "\xFF\x46\x4F\x4E\x54",
    "Windows international code page",
    "Windows"
  },
  .{
    "\xFF\xFE",
    "Windows Registry file",
    "Windows"
  },
  .{
    "\xFF\xFF\xFF\xFF",
    "DOS system driver",
    "Windows"
  },
};
