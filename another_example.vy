struct Funder:
  sender: address
  value: wei_value

funders: map(int128, Funder)
nextFUnderIndex: int128
# where the tokens are gonna go
beneficiary: address
# deadline is when you stop
deadline: public(timestamp)
goal: public(wei_value)
refundIndex: int128
# last time they can contribute
timelimit: public(timedelta)



### FUNCTIONS

# initialization function
# you need to state
@public
def __init__(_beneficiary: address, _goal: wei_value, _timelimit: timedelta):
  self.beneficiary = _beneficiary
  self.deadline = block.timestamp + _timelimit
  self.timelimit = _timelimit
  self.goal = _goal
  

# if you want perform transaction
# make it payable
@public
@payable
def participate():
    # you can check if the deadline is met
    # you can use assert and send message
  assert block.timestamp < self.deadline, "deadline not met yet"
  nfi: int128 = self.nextFunderIndex
    # set the mapping storage
    # Funder is defined before with sender and value
    # msg.sender is a built-in variable means who called the current function
    # msg.value is the amount of wei sent with the function called
    # they are assigned to sender and value fields for one instance of funder
  self.funders[nfi] = Funder({sender:msg.sender, value: msg.value})
    # increment the next index
  self.nextFunderIndex = nfi+1
    
@public
def finalize():
  assert block.timestamp >= self.deadline, "deadline"
  assert self.balance >= self.goal, "invalid balance"
    # stop the contract
  selfdestruct(self.beneficiary)
    
    
@public
def refund():
  assert block.timestamp >= self.deadline and self.balance < self.goal
  ind: int128 = self.refundIndex
  for i in range(ind, ind+30):
    if i >= self.nextFunderIndex:
      self.refundIndex = self.nextFunderIndex
      return
      send(self.funders[i].sender, send.funders[i].value)
      clear(self.funders[i])
        
    self.refundIndex = ind + 30
   