// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.6;
import "./DateUtils.sol";
import "./Flight.sol";
contract AirlineServer {
    using DateUtils for *;
    mapping(string => mapping(address => Flight)) _bookingList;  // use flight number or booking id for array index
    mapping(string => mapping(address => Flight)) _TempbookingList; 

    enum FlightState {ONTIME, DELAYED, CANCEL,DEPARTED}
    enum StateChangeType {NA,BEFORE24,AFTER24}
    struct Date{
        uint8  month;
        uint8  day;
        uint8  hour;
        uint8  minute;
        uint8  second;
        uint16 year;
    }
    address [2]  airline_address=[0xDa3F8B73079a9572C3f6580d2fF1aabbEd2C1A9a];
    address payable [] customer_address;

    struct FlightInfo {            //add any other details required 
        uint8 num_b_seat_left;
        uint8 num_e_seat_left;
        uint16 prize_b;
        uint16 prize_e;
        string flight_number;
        uint256 flight_date;
        FlightState flight_state;
        uint256 time_of_state_change;
        StateChangeType update_type;
        string source;
        string destination;
    }

    FlightInfo[] _flightarray;   
    FlightInfo _flightinfo;

    modifier ValidAirlineAddress (address _airline) {
        bool flag=false;
         for (uint8 i=0;i<airline_address.length;i++){     
            if (_airline==airline_address[i]){
            _;
            flag=true;
            break;
        }
        if (!flag){
            revert("Only airline can do this");
        }
    }
    }
    
    function contractBalance(address _userAddress, string calldata flight_number) public view ValidAirlineAddress(msg.sender) returns(uint256 balance) {
        Flight flight = _bookingList[flight_number][_userAddress];
        return (address(flight).balance);
    }

    function registerFlight(uint8 _business_seat, uint8 _economy_seat, string memory _flight_number,Date memory _flight_date,
        string memory _source,string memory _destination,uint16 _prize_b,uint16 _prize_e) public ValidAirlineAddress(msg.sender) {
        uint8 i=0;
        for (i=0;i<_flightarray.length;i++){
            if (sha256(abi.encodePacked(_flight_number))==sha256(abi.encodePacked(_flightarray[i].flight_number))){
                revert("Flight already exist");
            }
        }
         uint256 tempTS=DateUtils.convertYMDHMStoTimestamp(_flight_date.year,_flight_date.month,_flight_date.day,_flight_date.hour,_flight_date.minute,_flight_date.second);
         _flightinfo= FlightInfo({
                                    num_b_seat_left:_business_seat,
                                    num_e_seat_left:_economy_seat,
                                    flight_number:_flight_number,
                                    flight_date:tempTS,
                                    flight_state:FlightState.ONTIME,
                                    time_of_state_change:0,
                                    update_type:StateChangeType.NA,
                                    source:_source,
                                    destination:_destination,
                                    prize_b:_prize_b,
                                    prize_e:_prize_e
        });
        _flightarray.push(_flightinfo);
    }

    function bookFlight(string memory flight_number, uint8 num_seat, uint8 seat_type) public {
        uint8 i=0;
        bool valid_flight=false;
        for (i=0;i<_flightarray.length;i++){
            if (sha256(abi.encodePacked(flight_number))==sha256(abi.encodePacked(_flightarray[i].flight_number))){
                valid_flight=true;
                break;
            }
        }
        require(valid_flight==true,"Invalid Flight Number");
        require(_flightarray[i].flight_state!=FlightState.CANCEL,"Flight Already Cancelled");
        require(_flightarray[i].flight_state!=FlightState.DEPARTED,"Flight Already Departed");

        Flight flight = new Flight(_flightarray[i],num_seat,msg.sender);
        
        if(flight.book(num_seat,seat_type))
        {
            flight.setSeatType(seat_type);
            _TempbookingList[flight_number][msg.sender] = flight; 
        }else{  
            flight.kill(msg.sender);
        } 
    }

    function showFlight() public view returns (FlightInfo[] memory flight_info) {
        return (_flightarray);
    }

    function confirmBooking(string memory flight_number) public payable {
    require(_TempbookingList[flight_number][msg.sender].confirm(msg.sender.balance),"Not enough Balance"); 
     Flight flight = _bookingList[flight_number][msg.sender]=  _TempbookingList[flight_number][msg.sender];
        require (msg.value==flight.amount(),"Amount mismatch");
        delete _TempbookingList[flight_number][msg.sender];
        flight.takePayment{value:msg.value}(block.timestamp);
        uint8 i;
        for (i=0;i<_flightarray.length;i++){
            if (sha256(abi.encodePacked(flight_number))==sha256(abi.encodePacked(_flightarray[i].flight_number))){
               break;
            }
        }

        if(flight.getSeatType()==1){                  
            _flightarray[i].num_b_seat_left =_flightarray[i].num_b_seat_left - flight.getNumberOfSeats();
        }else{
            _flightarray[i].num_e_seat_left =_flightarray[i].num_e_seat_left - flight.getNumberOfSeats();
        }
        customer_address.push(payable(msg.sender));
    }

    function changeFlightTime(string memory flight_number, Date memory datetime) public ValidAirlineAddress(msg.sender) {
        uint i=0;
        uint j=0;
        for (j=0;j<_flightarray.length;j++){
            if (sha256(abi.encodePacked(flight_number))==sha256(abi.encodePacked(_flightarray[j].flight_number))){
               break;
                }
            }  
        for(i=0;i<customer_address.length;i++){
            Flight flight=_bookingList[flight_number][customer_address[i]]; 
            uint256 tempTS=DateUtils.convertYMDHMStoTimestamp(datetime.year,datetime.month,datetime.day,datetime.hour,datetime.minute,datetime.second);
            if(flight.changetime(tempTS,customer_address[i])){
                _flightarray[j].update_type=StateChangeType.BEFORE24;
            }else{
                _flightarray[j].update_type=StateChangeType.AFTER24;
            }
            _flightarray[j].flight_state=FlightState.DELAYED;
        }
    }

    function cancelBooking(string memory flight_number) public {
        Flight flight = _bookingList[flight_number][msg.sender];
        flight.cancel(msg.sender);
        //flight.kill(msg.sender);
    }
       
    function cancelbyFlight(string memory flight_number) public ValidAirlineAddress(msg.sender) {
        uint i=0;
        uint j=0;
        for (j=0;j<_flightarray.length;j++){
            if (sha256(abi.encodePacked(flight_number))==sha256(abi.encodePacked(_flightarray[j].flight_number))){
               break;
                }
            }
        for(i=0;i<customer_address.length;i++){
            Flight flight=_bookingList[flight_number][customer_address[i]];
            flight.cancelflight(customer_address[i]);
        }
        _flightarray[j].flight_state=FlightState.CANCEL;
    }

    function flightTakeOff(string memory flight_number) public ValidAirlineAddress(msg.sender) {
        uint i=0;
        uint j=0;
        for (j=0;j<_flightarray.length;j++){
            if (sha256(abi.encodePacked(flight_number))==sha256(abi.encodePacked(_flightarray[j].flight_number))){
               break;
                }
            }
        for(i=0;i<customer_address.length;i++){
            Flight flight=_bookingList[flight_number][customer_address[i]];
            flight.takeoff();
            _flightarray[j].flight_state=FlightState.DEPARTED;
        }
    }
}
