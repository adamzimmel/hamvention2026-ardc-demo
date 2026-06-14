#!/usr/bin/env bash
set -u
set -o pipefail

# Designed for an 80x24 VT102-compatible display.
# Usage: ./ardc_vt102_port_8n1.sh [/dev/ttyUSBx]
PORT="${1:-/dev/ttyUSB1}"
TEXT_WIDTH=68
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
GRANTS_FILE="${GRANTS_FILE:-$SCRIPT_DIR/grants.tsv}"

if [[ ! -e "$PORT" ]]; then
    echo "Error: $PORT does not exist." >&2
    exit 1
fi

if [[ ! -w "$PORT" ]]; then
    echo "Error: $PORT is not writable. Try sudo or add your user to the dialout group." >&2
    exit 1
fi

for cmd in stty fold sed seq sleep dirname; do
    command -v "$cmd" >/dev/null || {
        echo "Error: required command '$cmd' not found." >&2
        exit 1
    }
done

OLD_STTY=$(stty -F "$PORT" -g)

# Configure serial port for VT102: 9600 baud, 8 data bits, no parity, 1 stop bit.
# ixon/ixoff enables XON/XOFF software flow control so ^S/^Q are handled properly.
stty -F "$PORT" 9600 cs8 -parenb -cstopb ixon ixoff -crtscts

# Send normal script output from printf, cat, sed, fold, etc. to the VT102.
exec > "$PORT"

hide_cursor(){ printf '\033[?25l'; }
show_cursor(){ printf '\033[?25h'; }
clear_screen(){ printf '\033[0m\033[2J\033[H'; }
move_cursor_bottom_right(){ printf '\033[24;80H'; }

# Print a complete screen/update, then park the cursor at the lower-right
# corner of the 80x24 VT102 display.
park_cursor(){ move_cursor_bottom_right; }

cleanup() {
    printf '\033[0m'
    show_cursor
    stty -F "$PORT" "$OLD_STTY" 2>/dev/null || true
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

wrap(){ fold -s -w "$TEXT_WIDTH"; }

type_out(){
    while IFS= read -r line; do
        printf "%s\n" "$line"
        park_cursor
        sleep 0.035
    done
}

# Pace full-screen writes so the VT102/serial adapter is not flooded.
# Heredocs always include the newline before the closing EOF marker. Read the
# whole block first, then emit CRLF only *between* rows so a 24-row screen does
# not get an extra line feed after the last row. If the final row reaches column
# 80, emit CR before any later escape sequence so VT autowrap cannot scroll.
screen_out(){
    local -a lines=()
    local line
    local i last_index

    while IFS= read -r line; do
        lines+=("$line")
    done

    # Drop one accidental blank row immediately before EOF. This is the common
    # heredoc formatting trap that shows up as an extra blank line on-screen.
    if [[ ${#lines[@]} -gt 0 && -z "${lines[-1]}" ]]; then
        unset 'lines[-1]'
    fi

    last_index=$((${#lines[@]} - 1))
    for i in "${!lines[@]}"; do
        if [[ "$i" -gt 0 ]]; then
            printf '\r\n'
        fi
        printf '%s' "${lines[$i]}"
        sleep 0.01
    done

    if [[ "$last_index" -ge 0 && ${#lines[$last_index]} -ge 80 ]]; then
        printf '\r'
    fi

    park_cursor
}

# Same pacing, but leaves the cursor after the emitted text for partial screens.
# It does not trim the final newline because following output needs to continue
# on the next row.
screen_out_continue(){
    while IFS= read -r line; do
        printf "%s\r\n" "$line"
        sleep 0.01
    done
}

countdown(){
    for i in $(seq 10 -1 1); do
        printf '\033[22;1H'
        printf "+------------------------------------------------------------------------------+\n"
        printf "| NEXT GRANT IN: %2d SECONDS                                                    |\n" "$i"
        printf '+------------------------------------------------------------------------------+'
        park_cursor
        sleep 1
    done
}

funding_screen(){
clear_screen
screen_out <<'EOF'
+------------------------------------------------------------------------------+
|                              ARDC GRANTS 2025                                |
+------------------------------------------------------------------------------+
|                                                                              |
|                    About $3.6 million distributed                            |
|                                                                              |
|                    79 projects funded                                        |
|                    127,000+ people impacted worldwide                        |
|                                                                              |
+------------------------------------------------------------------------------+
EOF

for i in $(seq 1 8); do
    printf '\033[5;22H%s' 'About $3.6 million distributed'
    sleep 0.25
    printf '\033[5;22H%s' "                              "
    park_cursor
    sleep 0.15
done

printf '\033[5;22H%s' 'About $3.6 million distributed'
park_cursor
sleep 4
}

ardc_logo_screen(){
clear_screen
screen_out <<'EOF'
          AAA               RRRRRRRRRR        DDDDDDDDDD            CCCCCCCCC
         AAAAA              RRRRRRRRRRR       DDDDDDDDDDDD       CCCCCCCCCCCCC
        AA   AA             RR       RRR      DDD       DDD     CCCC
       AAA   AAA            RR       RRR      DDD        DDD   CCCC
      AAAAAAAAAAA           RRRRRRRRRRR       DDD        DDD   CCC
     AAAAAAAAAAAAA          RRRRRRRRRR        DDD        DDD   CCC
     AAA       AAA          RR    RRR         DDD        DDD   CCCC
    AAA         AAA         RR      RRR       DDD       DDD     CCCC
   AAA           AAA        RR       RRR      DDDDDDDDDDDD       CCCCCCCCCCCCC
  AAA             AAA       RR        RRR     DDDDDDDDDDD           CCCCCCCCC 

                      AMATEUR RADIO DIGITAL COMMUNICATIONS

                               GRANTS  |  44NET

		                  VT102 DEMO
			              by
		            Adam Zimmel   - W0ZML
		            Aiden Schramm - W0MOD

EOF

for i in $(seq 1 18); do
    printf '\033[14;32H%-48s' "GRANTS  |  44NET"
    park_cursor
    sleep 0.18
    printf '\033[14;32H%-48s' "                "
    park_cursor
    sleep 0.18
done

printf '\033[14;32H%s' "GRANTS  |  44NET"
park_cursor
sleep 4

}

learn_experiment_build_screen(){
clear_screen

screen_out <<'EOF'
+------------------------------------------------------------------------------+
|                           LEARN  EXPERIMENT  BUILD                           |
+------------------------------------------------------------------------------+
|                                                                              |
|   ARDC supports projects involving:                                          |
|                                                                              |
|      * Amateur radio infrastructure                                          |
|      * Repeater modernization and expansion                                  |
|      * Emergency and disaster communications                                 |
|      * Open-source radio software                                            |
|      * SDR and digital communications                                        |
|      * Mesh networking and microwave links                                   |
|      * Satellite and ground station projects                                 |
|      * Youth STEM and classroom education                                    |
|      * University engineering and research                                   |
|      * Remote HF stations and online access                                  |
|      * High-altitude balloon and rocketry telemetry                          |
|      * Winlink, APRS, and digital messaging                                  |
|      * Radio astronomy and scientific experimentation                        |
|      * Public service and technical training                                 |
|      * Makerspaces, workshops, and licensing programs                        |
|      * International amateur radio development                               |
|                                                                              |
+------------------------------------------------------------------------------+
EOF

sleep 12
}

grant_stats_screen(){
clear_screen
screen_out <<'EOF'
+------------------------------------------------------------------------------+
|                              DID YOU KNOW?                                   |
+------------------------------------------------------------------------------+
|                                                                              |
|   In 2025, ARDC distributed about $3.6 million in grants.                    |
|                                                                              |
|   Since ARDC's grantmaking program began:                                    |
|                                                                              |
|                  127,000+ PEOPLE IMPACTED WORLDWIDE                          |
|                                                                              |
|   79 projects funded in 2025                                                 |
|                                                                              |
|   2025 funding by category:                                                  |
|                                                                              |
|      Amateur Radio .................                                         |
|      Education .....................                                         |
|      Research & Development ........                                         |
|      Scholarships ..................                                         |
|                                                                              |
+------------------------------------------------------------------------------+
EOF

for i in $(seq 1 20); do
    printf '\033[15;40H%s' "$(printf '%2d%%' $((i * 30 / 20)))"
    printf '\033[16;40H%s' "$(printf '%2d%%' $((i * 26 / 20)))"
    printf '\033[17;40H%s' "$(printf '%2d%%' $((i * 23 / 20)))"
    printf '\033[18;40H%s' "$(printf '%2d%%' $((i * 21 / 20)))"
    park_cursor
    sleep 0.08
done

sleep 12
}

rfc790_screen(){
clear_screen
screen_out <<'EOF'
+------------------------------------------------------------------------------+
|                               RFC 790                                        |
+------------------------------------------------------------------------------+
|                                                                              |
|   SEPTEMBER 1981                                                             |
|                                                                              |
|   044.rrr.rrr.rrr    AMPRNET    Amateur Radio Experiment Net                 |
|                                                                              |
|   Historical note:                                                           |
|                                                                              |
|      "Amateur" was misspelled as "Amature" in the RFC listing.               |
|                                                                              |
|                         044.rrr.rrr.rrr                                      |
|                                                                              |
+------------------------------------------------------------------------------+
EOF

for col in $(seq 26 46); do
    printf '\033[12;%sH*' "$col"
    park_cursor
    sleep 0.05
done

sleep 12
}

coffee_break_screen(){
clear_screen
screen_out <<'EOF'
+------------------------------------------------------------------------------+
|                              COFFEE BREAK                                    |
+------------------------------------------------------------------------------+
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                ________                                      |
|                               |        |                                     |
|                               | COFFEE |                                     |
|                               |        |                                     |
|                                '------'                                      |
|                                                                              |
|   FUN FACT:                                                                  |
|   This VT102 spent two years in an attic waiting for a reason to be fixed.   |
|                                                                              |
|   Apparently, Hamvention was a good enough excuse.                           |
|                                                                              |
+------------------------------------------------------------------------------+
EOF

for i in $(seq 1 48); do
    case $((i % 4)) in
        0) s1="        ( ("; s2="         ) )"; s3="   _____( (" ;;
        1) s1="         ) )"; s2="        ( ("; s3="   ______) )" ;;
        2) s1="        . ."; s2="         . ."; s3="   _____. ." ;;
        3) s1="         ( )"; s2="        ( )"; s3="   ______( )" ;;
    esac

    printf '\033[6;31H%s' "$s1"
    printf '\033[7;31H%s' "$s2"
    printf '\033[8;31H%s' "$s3"
    park_cursor

    sleep 0.25
done
}

matrix_screen(){
    # Draw the static RF display once, then animate only the 7x31 scope window.
    # Sine-wave window top-left: row 10, column 12.
    local top=10
    local left=12
    local width=31
    local frame row y x pos phase idx ch
    local rows

    clear_screen
    screen_out <<'EOF'
+------------------------------------------------------------------------------+
| Meter:RF DISPLAY                          | RF Control:       DUPLEX         |
| Mon Freq: 146.5200 MHz     Dev: 5.00 kHz  | Preset: --       B/W: WB         |
| Freq Err:+   10 Hz   Input Lvl:---.-- W   | Mon Freq:   146.5200 MHz         |
| Gen Freq: 146.5200 MHz     Lvl:707.10 uV  | Offset:      +00.000 MHz         |
|-------------------------------------------+ Mon: 40 dB        RF I/O         |
| Display: MODULATION SCOPE  Select: MON    | Gen: -050.0 dBm   RF I/O         |
| Trigger: AUTO       Trig Lvl:470(rel lvl) |                                  |
| Horiz: 10 ms/div     Position: <>         |----------------------------------|
|                                           | Mod Sum:      5.00 kHz           |
| Vertical:                                 | Fixed 1kHz:   1.00 kHz ~         |
|   1 kHz/                                  | Synth:        0.35 kHz           |
|     div                                   | Format Sel:         DPL          |
|            ------------------------       | Code:               423          |
|            __--__--__--__--__--__         | DTMF:         1.00 kHz x         |
|                                           | Code:-------------------         |
| Pos: (<>)                                 | External:     5.00 kHz ~         |
|-------------------------------------------+----------------------------------|
|                                                                              |
| [    ~   ] [   x   ] [ * START] [        ] [        ] [        ] [        ]  |
| [  CONT  ] [  OFF  ] [ DISC IN] [        ] [        ] [        ] [        ]  |
|                                                                              |
|                                                                              |
+------------------------------------------------------------------------------+
EOF

    # y lookup table for a 7-row sine-ish wave, indexed by (x + phase) % 16.
    # Values are 0..6, where 0 is the top row of the 7x31 window.
    local wave_y=(3 2 1 1 0 1 1 2 3 4 5 5 6 5 5 4)

    for frame in $(seq 0 89); do
        rows=( \
            "                               " \
            "                               " \
            "                               " \
            "                               " \
            "                               " \
            "                               " \
            "                               " \
        )

        for x in $(seq 0 $((width - 1))); do
            idx=$(((x + frame) % 16))
            y=${wave_y[$idx]}

            # Use heavier characters on the center/bottom rows for a CRT-scope look.
            case "$y" in
                0|1|2|3) ch='*' ;;
                *)       ch='_' ;;
            esac

            row=${rows[$y]}
            rows[$y]="${row:0:$x}$ch${row:$((x + 1))}"
        done

        for y in $(seq 0 6); do
            # Move to the window row and print exactly 31 chars, erasing the old frame.
            printf '\033[%d;%dH%-31.31s' "$((top + y))" "$left" "${rows[$y]}"
        done

        park_cursor
        sleep 0.08
    done
}

credits_screen(){
clear_screen
screen_out <<'EOF'
===============================================================================

                               A R D C
                         STAFF, BOARD, VOLUNTEERS

===============================================================================

STAFF                                   CONTRACTORS
  Rosy Schechter - KJ7RYV, CEO            Chris Smith - G1FEF, 44Net/IT
  Schuyler Erle - N0GIS, Tech Dir         Tim Pozar - KC6GNJ, Tech Mgmt
  Chelsea Parraga - KF0FVJ, Grants      
  Rebecca Key - KO4KVG, Comms           TECHNOLOGY PARTNERS
  Merideth Stroh - KK7BKI, Ops            The Communication Gateway
  Adam Lewis - KC7GDY, IT/Dev             Two P
  John Burwell - KI5QKX, 44Net            Open Tech Strategies
  Adam Zimmel - W0ZML, Grants/Admin     
EOF
sleep 6

clear_screen
screen_out <<'EOF'
===============================================================================

                               A R D C
                         STAFF, BOARD, VOLUNTEERS

===============================================================================

BOARD OF DIRECTORS                      2026 GRANTS ADVISORY COMMITTEE
  Bdale Garbee - KB0G, President          Chelsea Parraga - KF0FVJ, Staff
  Keith Packard - K7WQ, Secretary         Hillary Ramsey - AB1CD, Chair
  Ria Jairam - N2RJ, Treasurer            Kevin Reeve - N7RXE, Deputy Chair
  Phil Karn - KA9Q, Director              Dennis Derickson - AC0P
  John Gilmore - W0GNU, Director          David Burgess - KE2DSM
  Bob Witte - K0NR, Director              Kevin McQuiggin - VE7ZD/KN7Q
  Ashhar Farhan - VU2ESE, Director        Jim White - WD0E
  Harald Welte, Director                  Steve Bunting - M0BPQ
                                          Gene Schroeder - AE8GS
                                          Dave Ginsberg - N3BKV
                                          Rob Warren - VE3RWQ
                                          Phil Flack - N4MT
                                          Paul Andrews - W2HRO
                                          Tim Annable - WW8L
EOF
sleep 6

clear_screen
screen_out <<'EOF'
===============================================================================

                               A R D C
                         STAFF, BOARD, VOLUNTEERS

===============================================================================

2026 TECHNICAL ADVISORY COMMITTEE       2025 CONDUCT REVIEW COMMITTEE
  John Burwell - KI5QKX, Staff Lead       Keith Packard - K7WQ
  Dave Gingrich - K9DC                    Merideth Stroh - KK7BKI
  Ian Redden - VA3IAN                     Donni Katzovicz - W2BRU
  Dennis Mojado - AD6DM                   Don Prosnitz - N6PRZ
  Kevin Titmarsh - 2E0LSR               
  Dan Srebnick - K2IE                   
  Ronnie Montgomery - W0RDM             
  Mason Turner - AF4MT                  
  Donni Katzovicz - W2BRU               
  Cara Salter - NA1CL                   
  Mickey Kappes - KO6DOT                
  Stewart Bryant - G3YSX                
EOF
sleep 6

clear_screen
screen_out <<'EOF'
===============================================================================

                               A R D C
                         STAFF, BOARD, VOLUNTEERS

===============================================================================

2026 GRANTS EVALUATION TEAM             2026 GRANTS COMMUNICATIONS TEAM
  Chelsea Parraga - KF0FVJ, Staff         Adam Zimmel - W0ZML, Staff Lead
  Falcon Momot - AF7MH, Chair             Jayadevan Gurubalan - VU33JD
  Willi Kraml - OE1WKL                    Steve Stroh - N8GNJ
  Scott Czeck - KC1GHT                    James Ewing - KC1UDQ
  Darryl Smith - VK2TDS                   Stuart Murray - NV4T
  Lad Nagurney - WA3EEC                 
  Don Prosnitz - N6PRZ                  COMMUNITY AMBASSADORS
  Wayne Heinen - N0POH                    Bill Thomas - WT0DX, Alumni Liaison
  Jim Idelson - K1IR                      Jann Traschewski - DG8NGN, HAMNET
  Tithira Jayasekera - 4S6TKA           
EOF
sleep 6

}
grant_screen(){
    IFS='|' read -r title date amount body <<< "$1"

    clear_screen

    screen_out_continue <<EOF
+------------------------------------------------------------------------------+
|                            2025 GRANT SPOTLIGHT                              |
+------------------------------------------------------------------------------+
| TITLE : $(printf "%-69s" "$title")|
| DATE  : $(printf "%-69s" "$date")|
| AMOUNT: $(printf "%-69s" "$amount")|
+------------------------------------------------------------------------------+

EOF

    printf "%s\n" "$body" | wrap | sed 's/^/  /' | while IFS= read -r line; do
        printf "%s\r\n" "$line"
    done

    countdown
}

if [[ -r "$GRANTS_FILE" ]]; then
    mapfile -t grants < "$GRANTS_FILE"
else
    # Fallback data keeps this script self-contained when grants.tsv is not present.
    mapfile -t grants <<'GRANTS'
FieldLab W0CY|October 2025|$35,640|Central Kansas Amateur Radio Club is building FieldLab, a mobile STEM and amateur radio lab for rural schools and local events. It will support electronics, satellite, and radio programming outreach while giving the club a reusable platform for training and public service.
Utah Tech S-Band Ground Station|October 2025|$13,176|Utah Tech University is adding an S-band ground station for its Solace CubeSat mission. The station will support higher data downlinks, connect to SatNOGS for public access, and include a portable demo setup for classrooms and events.
New Class Opportunities|October 2025|$7,051|The Vintage Radio and Communications Museum of Connecticut is adding build-focused youth classes. Students will assemble an FM receiver, learn soldering and electronics basics, and optionally explore a 40-meter amateur radio version.
Coastside Emergency Communications Trailer|October 2025|$25,000|Half Moon Bay Amateur Radio Club is building a small communications trailer with operator positions, portable antennas, and solar power. It will support shelters, emergency hubs, remote areas, CERT partners, and public events.
AMSAT BuzzSat Online Courses|October 2025|$14,556|AMSAT is developing fourteen BuzzSat online courses explaining how satellites help everyday life. Funding supports lesson authoring tools and improved artwork so students, families, and educators can use the materials for free.
Open-Source Passive Radar Legal Framework|October 2025|$19,632|Offworld Lab is developing legal guidance for open-source passive radar work. The project addresses export-control questions so developers, clubs, and researchers can continue passive radar experimentation with clearer rules.
New VHF Repeater|October 2025|$9,143|Trilogy Amateur Radio Club will install a new VHF repeater to fill coverage gaps in East Pierce County. The system will improve routine communication, ARES operations, severe weather response, and local operator access.
Leffell School Space Program Ground Station|October 2025|$31,200|The Leffell School is adding a full satellite ground station for its student space program. Students will track satellites, build and test antennas, use VHF and UHF equipment, decode live signals, and prepare for ham licenses.
Ellis County ARES Digital Expansion|October 2025|$13,950|Ellis County ARES will add two linked digital repeaters in Trego and Rush counties. The expanded network will improve coverage for spotters and emergency officials during severe weather and wildfire activity.
Matane Quebec Club HF Station III|October 2025|$8,704|The Matane Amateur Radio Club is installing a permanent HF station with Winlink, backup power, and remote control. It will support emergency communication, public demos, digital mode training, and regional exercises.
RARS Portable Ground Station|October 2025|$14,065|Raleigh Amateur Radio Society will build a portable ARISS and satellite ground station. The ready-to-deploy station will support schools, youth activities, training, and space communications demos.
West Central Louisiana Repair|October 2025|$6,723|West Central Louisiana Amateur Radio Club will replace damaged equipment, upgrade repeater components, and repair tower infrastructure. The work restores wide-area coverage, APRS capability, and emergency communication access.
Case Senior Project Support|October 2025|$3,500|The Case Amateur Radio Club at Case Western Reserve University will support radio engineering senior projects. Students will use club station and lab resources while documenting experimental designs under supervision.
Northwest New Mexico Winlink Digipeater|October 2025|$7,100|Northwest New Mexico EMCOMM Group will install a Winlink RMS and VARA FM digipeater backed by Starlink. The project supports rural digital messaging, tower and power installation, testing, and on-air training.
Hot Springs Education and Repeaters|October 2025|$11,730|Hot Springs Amateur Radio Club will install three Yaesu DR2X repeaters and support youth licensing with exam fees, guides, handheld radios, and memberships. The project improves coverage and local emergency readiness.
Dimension Parabole Radio Telescope|October 2025|$22,000|Dimension Parabole will repair and upgrade a 10-meter radio telescope in La Villette Park, France. The work restores reliable operation, adds high-frequency capability, and supports demos, youth activities, and radio astronomy.
AMSAT KidzSat Coloring Book|October 2025|$4,500|AMSAT will publish a children's coloring book showing how satellites support weather, navigation, communications, wildfire detection, and other daily uses. The book will be freely available through KidzSat.
OMIK Scholarship Funding|October 2025|$15,000|OMIK Amateur Radio Association will support its 2025 to 2026 scholarship cycle. The program helps students continue postsecondary education while encouraging growth in amateur radio.
South Mountain Radio Amateurs Education|October 2025|$19,186|SMRA will train 100 new operators through recurring Technician classes in Cumberland County, Pennsylvania. The project includes study materials, exam support, radios, mentoring, and upgraded VHF, UHF, DMR, and HF equipment.
OpenMesh Voice Network|October 2025|$33,000|OpenMesh Voice Network is building an open, low-cost 70 cm mesh system for real-time voice and data. Funding supports hardware design, compliance testing, beta units, apps, documentation, and field deployment.
Seagull Solar Racing Team|October 2025|$7,509|Seagull Solar Racing Team will add amateur radio training and VHF/UHF equipment to its high school solar car program. The project supports race operations, student licensing, safety, and open guides for other schools.
Hamlib Stability and SDR Support|August 2025|$94,724|OH3AA will modernize Hamlib, the open-source radio control library used by tools like WSJT-X and fldigi. The project adds automated testing and support for modern SDR and network-controlled radios.
Meshtastic for Wildfire Fighters|August 2025|$57,068|WildfireMesh will introduce Meshtastic LoRa networking to firefighter brigades in Argentina. The team will provide equipment kits, Spanish-language guides, field testing, and workshops for backup emergency communications.
Waves of Innovation Makerspace|August 2025|$5,000|The Innovation School will create a middle school digital communications makerspace. Students will build antennas, use SDRs, try digital modes, track progress, and work with local ham volunteers.
Remote HF Station for Youth|August 2025|$34,169|Thanet Radio Infrastructure Group and Hilderstone Radio Society will build a remote HF station for schools and youth groups in East Kent. It gives supervised access to HF radio without needing local antennas.
Illinois Space Society Tracking Systems|August 2025|$5,766|Illinois Space Society will build tracking and communication systems for student rockets. The project upgrades a portable ground station and develops a satellite communication board with open-source designs.
STEM ARC Youth Hobby Project|August 2025|$18,075|STEM Amateur Radio Club will expand school and scouting outreach, youth training, emergency workshops, and licensing support. The project provides materials, radios, and hands-on activities for young operators.
Roberts Repeater Relocation|August 2025|$11,040|St. Croix County ARES/RACES will move the Roberts repeater to a county tower for a stable long-term site. The relocation supports SKYWARN, emergency communication, and public events.
WLSAR Emergency Communications|August 2025|$28,282|WLSAR will upgrade the Maple, Wisconsin repeater site and build a linked digital network with antennas, battery backup, internet, HVAC, and security. The system supports ARES, emergencies, races, and public events.
New England Sci-Tech Digital Radio|August 2025|$42,565|New England Sci-Tech will expand digital radio education with workshops, license courses, SDR and digital mode clubs, balloon work, scout labs, radios, exam support, and updated lab equipment.
Boundary County Radio Improvements|August 2025|$9,394|Boundary Amateur Radio Club will update radios, add portable field equipment, and improve the main repeater. The project supports fire crews, hospital staff, emergency response, and local events.
JCARC Building Renovation|August 2025|$39,334|Jay County Amateur Radio Club will renovate a fairgrounds space into a permanent clubhouse with wiring, insulation, HVAC, ADA access, training areas, testing space, and operating stations.
Valencia Middle School Radio Program|August 2025|$24,570|VCARA will sustain and expand Valencia Middle School's amateur radio program with study books, handhelds, antennas, repeater upgrades, field trips, and classroom lab supplies.
Radio Reimagined Brooklyn Youth|August 2025|$25,000|Black Girls Do Engineer will introduce up to 50 girls ages 10 to 18 to amateur radio and digital communications through licensing, RF basics, SDR, Arduino, packet radio, mentoring, and a showcase.
Pima Community College Radio Shack|August 2025|$11,910|K7PCC will create a permanent campus radio shack with HF, VHF/UHF stations, antennas, and test equipment. The station gives students practical experience with voice, digital operations, and RF systems.
LMARS Repeater Upgrade|August 2025|$9,179|Lake Monroe Amateur Radio Society will upgrade and relocate its 2-meter repeater to Orlando Health Lake Mary Hospital. The new analog FM and DMR system improves hospital and hurricane communication support.
Sri Lanka Emergency Communication Resilience|August 2025|$3,850|Radio Society of Sri Lanka will deploy portable grid-independent HF and VHF stations, provide handheld radios to trained volunteers, and establish Sri Lanka's first Winlink gateway.
Ege University IoT Link Monitoring|August 2025|Amount TBD|Ege University will research energy-efficient monitoring for wireless IoT networks using ESP32 devices. The team will publish open-source tools, data, and documentation for students, educators, and researchers.
BCAFMA Duplexer|August 2025|$7,000|Butler County Amateur FM Association will replace a 50-year-old duplexer with a new six-cavity model. The upgrade restores wide-area repeater coverage and improves handheld access for newcomers.
Trans-Quebec RF Network|August 2025|$74,787|Quebec's amateur radio federation will repair, improve, and expand the RTQ linked repeater network. Upgrades include replacing aging equipment, adding sites, and improving reliability in harsh winter conditions.
Milford Digital Coverage Expansion|August 2025|$16,181|Milford Amateur Radio Club will move its Wires-X digital repeater to a higher site, expanding coverage across Ohio, Kentucky, and Indiana while improving handheld access and digital mode outreach.
Vallee du Richelieu Modernization|August 2025|$32,468|VE2CVR will replace aging repeater systems at hospital and military base sites with modern equipment, improving daily operations, emergency reliability, and public service support.
OVARC VHF Repeater Revitalization|August 2025|$24,750|Okaw Valley Amateur Radio Club will revitalize its VHF repeater with a new shelter, generator, repaired link antenna, and environmental controls for emergency response, events, and student training.
Northwest Indiana Radio Outreach|May 2025|$27,462|Porter County Amateur Radio Club will deploy a 7x14 enclosed trailer as a mobile radio hub for school outreach, scouting, county events, STEM education, and emergency communications.
Hamnet Expansion in Lublin|May 2025|$8,693|Radiokomunikacja Kryzysowa will expand HAMNET in eastern Poland by adding access points, linking to the Lublin backbone, relaunching a school radio club, and mentoring students.
Ontario Tech Mobile Repeater|May 2025|$19,053|Ontario Tech students will build a mobile dual-band VHF/UHF repeater and ground station to support rocketry launches, campus events, public demos, and student licensing.
PVTAC Microwave and Simulcast Expansion|May 2025|$170,356|PVTAC will expand its 10 GHz microwave network, connect mountaintop sites, improve Ventura County communications, add solar upgrades, and support DMR, AllStar, HDTV, ROIP, cameras, and other digital modes.
GRANTS
fi

if [[ ${#grants[@]} -eq 0 ]]; then
    echo "Error: no grant records loaded." >&2
    exit 1
fi

hide_cursor

grant_index=0
batch_count=0
total_grants=${#grants[@]}


ardc_logo_screen
learn_experiment_build_screen
grant_stats_screen
rfc790_screen
matrix_screen


while true; do

    shown=0

#    credits_screen

#    coffee_break_screen
#    matrix_screen

    while [ "$shown" -lt 4 ]; do
        #funding_screen
        grant_screen "${grants[$grant_index]}"

        grant_index=$((grant_index + 1))
        shown=$((shown + 1))

        if [ "$grant_index" -ge "$total_grants" ]; then
            grant_index=0
        fi
    done

    batch_count=$((batch_count + 1))

    ardc_logo_screen

    if [ $((batch_count % 3)) -eq 10 ]; then
        coffee_break_screen
    fi

    if [ $((batch_count % 3)) -eq 0 ]; then
        matrix_screen
    fi

    learn_experiment_build_screen
    grant_stats_screen

    if [ $((batch_count % 2)) -eq 0 ]; then
        rfc790_screen
    fi

    if [ $((batch_count % 7)) -eq 0 ]; then
        credits_screen
    fi

done
