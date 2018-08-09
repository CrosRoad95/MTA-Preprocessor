#define DEBUG

#define TYPE(E,T) getElementType(E) == T
#define IS_PLAYER(E) getElementType(E) == "player"
#define IS_VEHICLE(E) getElementType(E) == "vehicle"
#define HAVE_VEHICLE(E) not not getPedOccupiedVehicle(E)
#define FOREACH(I,V,T) for I=1,#T do V = T[I];
#define LEN(S) string.len(S)
#define EMPTY(S) string.len(S) == 0 
#define CONTAIN(S,C) string.find(S,C) ~= 0
#define BETWEEN(A,B,C) A >= B and C <= A
#define EDIS(A,B) getDistanceBetweenPoints3D(Vector3(getElementPosition(A)),Vector3(getElementPosition(B)))
#define DISTANCE2D(X1,Y1,X2,Y2) math.sqrt((X2 - X1) ^ 2 + (Y2 - Y1) ^ 2)
#define DISTANCE(X1,Y1,Z1,X2,Y2,Z2) math.sqrt((X2 - X1) ^ 2 + (Y2 - Y1) ^ 2 + (Z2 - Z1) ^ 2)
#define TABLESIZE(T) (function(t) local length = 0 for _ in pairs(t) do length = length + 1 end return length end)(T)
#define INSIDE(CX,CY,PX,PY,PSX,PSY) CX >= PX and CX <= PX + PSX and CY >= PY and CY <= PY + PSY

#define THISTEXTURES(N) getElementsByType("texture", resourceRoot)
#define PLAYERS() getElementsByType("player")
#define VEHICLES() getElementsByType("vehicle")