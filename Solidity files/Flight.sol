// SPDX-License-Identifier: UNLICENSED
pragma solidity  >=0.8.0;
import "./EagleServer.sol";
contract Flight {
    enum FlightState {ONTIME, DELAYED, CANCEL,DEPARTED}
    enum BookingState {NA,INITIATED, CONFIRMED, CANCEL, FAILED}
    enum StateChangeType {NA,BEFORE24,AFTER24}
   
    struct FlightData {           
        BookingState booking_state; 
        uint8 num_b_seat_left;
        uint8 num_e_seat_left;
        uint16 prize_b;
        uint16 prize_e;
        string flight_number;
	    address customer;
        uint256 flight_date;
        AirlineServer.FlightState flight_state;
        uint256 time_of_state_change;
        AirlineServer.StateChangeType update_type;
        string source;
        string destination;
        uint8 seat_type;
        uint8 num_seat_book;
        string order_id;
        uint256 time_of_booking;
    }
    
    FlightData _flightData;
    address [2]  airline_address=[0xDa3F8B73079a9572C3f6580d2fF1aabbEd2C1A9a];
    
    constructor(AirlineServer.FlightInfo memory flightDataInfo ,uint8 _num_seat_book,address _customer) {
        _flightData = FlightData({
                                            booking_state: BookingState.NA,
                                            num_b_seat_left: flightDataInfo.num_b_seat_left,
                                            num_e_seat_left:flightDataInfo.num_e_seat_left,
                                            flight_number:flightDataInfo.flight_number,
	                                        customer: _customer,
                                            flight_date:flightDataInfo.flight_date,
                                            flight_state:flightDataInfo.flight_state,
                                            time_of_state_change:flightDataInfo.time_of_state_change,
                                            update_type:flightDataInfo.update_type,
                                            source:flightDataInfo.source,
                                            destination:flightDataInfo.destination,
                                            prize_b:flightDataInfo.prize_b,
                                            prize_e:flightDataInfo.prize_e,
                                            seat_type:0,
                                            num_seat_book:_num_seat_book,
                                            order_id:"",
                                            time_of_booking:0
                            });
    }

    function amount() public returns (uint64){
        uint64 amountToBeTranfered=_flightData.seat_type==0? (_flightData.prize_e*_flightData.num_seat_book):(_flightData.prize_b*_flightData.num_seat_book);
        return (amountToBeTranfered);
    }

    function takePayment(uint256 time) public payable {
        require (_flightData.booking_state!=BookingState.CONFIRMED,"Already paid");
        _flightData.booking_state=BookingState.CONFIRMED; 
        _flightData.time_of_booking=time;
        if(_flightData.seat_type==1){                  
         _flightData.num_b_seat_left =_flightData.num_b_seat_left - _flightData.num_seat_book;
        }else{
            _flightData.num_e_seat_left =_flightData.num_e_seat_left - _flightData.num_seat_book;
        }
    }

    function setSeatType(uint8 _seattype) public{
        _flightData.seat_type=_seattype;
    }

    function getSeatType() public returns(uint8){
        return _flightData.seat_type;
    }

    function getNumberOfSeats() public returns(uint8){
        return _flightData.num_seat_book;
    }

    function confirm(uint256 _amount) public returns (bool){
        require(_flightData.booking_state==BookingState.INITIATED,"Initate valid booking first");
        if(_flightData.seat_type==0 && _amount<(_flightData.prize_e*_flightData.num_seat_book) || _flightData.seat_type==1 && _amount<(_flightData.prize_b*_flightData.num_seat_book) ){
           return false;
        }else{
            return true;
        }
    }

    function kill( address sender) external{
        selfdestruct(payable(sender));
    }

    function book(uint8 num_seat,uint8 seat_type) public returns (bool){
        require ((_flightData.booking_state!=BookingState.INITIATED)||(_flightData.booking_state!=BookingState.CONFIRMED),"Booking already in process/done");
        if((seat_type==0 && _flightData.num_e_seat_left>=num_seat) || ( seat_type== 1 && _flightData.num_b_seat_left>=num_seat) )
        {   _flightData.booking_state=BookingState.INITIATED;
            return true;
        }else{
            _flightData.booking_state=BookingState.FAILED;
            return false;
        }
    }

    function cancel(address user) public {
        //checking if cancel within time frame and deduct accordingly wrt time difference
        if(block.timestamp<(_flightData.flight_date-7200)){
            payable(user).transfer(address(this).balance * ((_flightData.flight_date-block.timestamp)/(_flightData.flight_date-_flightData.time_of_booking)));
        }
        _flightData.booking_state=BookingState.CANCEL; 
        payable(0xDa3F8B73079a9572C3f6580d2fF1aabbEd2C1A9a).transfer(address(this).balance);     
    }

    function cancelflight(address payable user) public {
        user.transfer(address(this).balance);
        _flightData.booking_state=BookingState.CANCEL;
        _flightData.flight_state=AirlineServer.FlightState.CANCEL; 
    }

    function changetime(uint256 _new_Date, address payable user) public payable returns (bool){
        uint256 tempTime= _flightData.flight_date-86400;
        _flightData.flight_state=AirlineServer.FlightState.DELAYED;
        _flightData.flight_date=_new_Date;
        _flightData.time_of_state_change=block.timestamp;
        if(_flightData.time_of_state_change <= tempTime){
            _flightData.update_type=AirlineServer.StateChangeType.BEFORE24;
            // transfer delay penalty to customer based on difference in original and new flight time
            user.transfer(address(this).balance * ((_flightData.flight_date-tempTime-86400)/86400));
            return true;
         }else{
              _flightData.update_type=AirlineServer.StateChangeType.AFTER24;
              user.transfer(address(this).balance);
              return false;
         }
    }

    function takeoff() public {
        _flightData.flight_state=AirlineServer.FlightState.DEPARTED;
        payable(0xDa3F8B73079a9572C3f6580d2fF1aabbEd2C1A9a).transfer(address(this).balance);
    } 
}
