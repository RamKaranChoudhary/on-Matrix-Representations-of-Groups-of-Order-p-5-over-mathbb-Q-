freeze;

/*
New Rational Meataxe.
AKS, Feb 2007.
*/

/*******************************************************************************
				Verbose
*******************************************************************************/

// declare verbose ZRepsKnapsack, 2;

// import "meataxe.m": MarkIrreducible, MarkIrreducibleSeq, MarkReducible;

/*******************************************************************************
				Defines
*******************************************************************************/

Z := IntegerRing();
Q := RationalField();

IsZQ := func<R | Type(R) in {RngInt, FldRat}>;

/*******************************************************************************
				Copy info
*******************************************************************************/

procedure copy_info(MZ, M)
    if assigned MZ`IsIrreducible and not assigned M`IsIrreducible then
	M`IsIrreducible := MZ`IsIrreducible;
    end if;
    if assigned MZ`SchurIndex then
	M`SchurIndex := MZ`SchurIndex;
    end if;
    if assigned MZ`Character then
	M`Character := MZ`Character;
    end if;
end procedure;

procedure copy_info_seq(MZQ, MQ)
    for i := 1 to #MZQ do
	copy_info(MZQ[i], MQ[i]);
    end for;
end procedure;

/*******************************************************************************
			    Write over Z
*******************************************************************************/

function write_over_Z(M)
    R := BaseRing(M);
    assert R cmpeq Q;

    n := Dimension(M);
    L := [MatrixRing(Z, n) | ];
    D := [IntegerRing() | ];
    for i := 1 to Nagens(M) do
	X, d := ClearDenominator(ActionGenerator(M, i));
	Append(~L, X);
	Append(~D, d);
    end for;

    if Type(M) eq ModGrp and forall{d: d in D | d eq 1 } then
	MZ := GModule(Group(M), L);
    else
	MZ := RModule(L);
    end if;

    return MZ, D;
end function;

/*******************************************************************************
			    Decomposition
*******************************************************************************/

intrinsic InternalDecomposition(M::ModRng) -> []
{Internal}

/*
"Decomp";
M: Magma;
M: Maximal;
*/
    if assigned M`Decomposition then
	return M`Decomposition;
    end if;

    R := BaseRing(M);
    if R cmpeq Z then
	return IntegralDecomposition(M);
    end if;

    if Type(M) eq ModGrp then
	G := Group(M);

	G_ORDER_LIMIT := 1000;
	DEG_FACTOR := 5;
	if #G le G_ORDER_LIMIT or assigned G`RationalCharacterTable then
	    RC := RationalCharacterTable(G);
	    d := Dimension(M);
	    if DEG_FACTOR * Degree(RC[#RC]) le d then
		L := InternalIrreducibleIntegralModules(G);
//"Got L:", L;
		res := [];
		for t in L do
//"t:", t;
		    D := InternalDecomposition(ChangeRing(t[1], R));
//"D:", D;
		    seen := 0;
		    for U in D do
//"U:", U;
//"U endo:", EndomorphismRing(U);
			for h in Basis(AHom(U, M)) do
//"h:", h;
//"    ", Parent(h);
			    rs := Rowspace(h);
			    if seen cmpeq 0 then
				seen := rs;
			    else
				nseen := seen + rs;
				if Dimension(nseen) lt
				    Dimension(seen) + Dimension(rs)
				then
				    //"\tSkip";
				    continue;
				end if;
				seen := nseen;
			    end if;

			    //"\tNEW";
			    Append(
				~res, ImageWithBasis(h, M: Check := false)
			    );
			end for;
		    end for;
		end for;
		return res;
	    end if;
	end if;
    end if;

    if Type(R) in {FldNum, FldCyc, FldQuad} then
	return InternalDecompositionANF(M);
    end if;

    require R cmpeq Q: "Base ring must be Z or Q";

    MZ, D := write_over_Z(M);

    DZ := IntegralDecomposition(MZ);
    copy_info(MZ, M);

    if #DZ eq 1 then
	M`Decomposition := [M];
	return [M];
    end if;

    D := [];
    for SZ in DZ do
	BZ := Morphism(SZ, MZ);
	B := Matrix(Q, BZ);
	// "B:", B;
	S := ImageWithBasis(B, M: Check := false);
	//S := ImageWithBasis(B, M: Check := true); "CHECK S:", S; Action(S);
	// Could use D and SZ to get action.
	copy_info(SZ, S);
	Append(~D, S);
    end for;

    M`Decomposition := D;
    return D;

end intrinsic;

/*******************************************************************************
			    IsIrreducible
*******************************************************************************/

intrinsic InternalIsIrreducible(M::ModRng) -> []
{Internal}

    if assigned M`IsIrreducible then
	return M`IsIrreducible;
    end if;

    R := BaseRing(M);
    if R cmpeq Q then
	MZ, D := write_over_Z(M);
	l := InternalIsIrreducible(MZ);
    elif R cmpeq Z then
	S := IntegralDecomposition(M: IrreducibilityTest);
	l := #S eq 1;
    else
	S := InternalDecompositionANF(M: IrreducibilityTest);
	l := #S eq 1;
    end if;

// if assigned M`IsIrreducible then "Now", M`IsIrreducible, "l", l; end if;

    M`IsIrreducible := l;
    return l;

end intrinsic;

/*******************************************************************************
				Isomorphic test
*******************************************************************************/

function quick_non_iso_test(M1, M2)
    // Return whether M1 easily proven non-iso to M2
    if Dimension(M1) ne Dimension(M2) then
	return true;
    end if;
    nag := Nagens(M1);
    assert Nagens(M2) eq nag;
    //"quick_non_iso_test"; M1; M2;
    //printf "M1 := %m;\n", M1; printf "M2 := %m;\n", M2;
    for i := 1 to nag do
	if Trace(ActionGenerator(M1, i)) ne Trace(ActionGenerator(M2, i)) then
	    return true;
	end if;
    end for;
    for i := 1 to nag do
	mp1, cp1 := MinimalAndCharacteristicPolynomials(ActionGenerator(M1, i));
	mp2, cp2 := MinimalAndCharacteristicPolynomials(ActionGenerator(M2, i));
	if mp1 ne mp2 or cp1 ne cp2 then
	    return true;
	end if;
    end for;
    return false;
end function;

function iso_test_irr(M1, M2, WantT, Reverse)
    // M1 assumed irreducible and quick non_iso test done

    H := AHom(M1, M2);
    if Dimension(H) eq 0 then
	return true, false, _;
    end if;
    if not WantT then
	return true, true, _;
    end if;
    T := H.1;
    if Reverse then
	T := T^-1;
    else
	if not IsUnit(T) then
	    error "Bad AHom";
	    M1, M2, T;
	end if;
    end if;
    return true, true, T;
end function;

intrinsic InternalIsomorphismTest(M1::ModRng, M2::ModRng, WantT::BoolElt)
    -> BoolElt, BoolElt, Mtrx
{Internal}

    /*
    Try to test whether M1 isomorphic to M2; return whether successful,
    and if so, return whether isomorphic, and return iso matrix T *IFF* WantT
    given.
    */

    R := BaseRing(M1);
    require Type(R) in {RngInt, FldRat, FldNum, FldCyc, FldQuad}:
	"Base ring must be Z, Q or a number field";
    require BaseRing(M2) cmpeq R: "Incompatible rings";

    n := Dimension(M1);
    if Dimension(M2) ne n then
	return true, false, _;
    end if;

    l := false;

    // Can do anyway if group OK:
    if assigned M1`Character and assigned M2`Character then
	l := M1`Character eq M2`Character;
	if not l or not WantT then
	    return true, l, _;
	end if;
    else
	if quick_non_iso_test(M1, M2) then
	    return true, false, _;
	end if;
    end if;

    // Now l true => known iso

    if assigned M1`IsIrreducible and IsIrreducible(M1) then
	return iso_test_irr(M1, M2, WantT, false);
    end if;
    if assigned M2`IsIrreducible and IsIrreducible(M2) then
	return iso_test_irr(M2, M1, WantT, true);
    end if;

    G := 0;
    if Type(M1) eq ModGrp then
	G := Group(M1);
    elif Type(M2) eq ModGrp then
	G := Group(M2);
    end if;
    if G cmpne 0 then
	p := 2;
	while true do
	    p := NextPrime(p);
	    if #G mod p eq 0 then
		continue;
	    end if;
	    //K := GF(p);
	    try
		M1K := GModule(M1, p);
		M2K := GModule(M2, p);
	    catch e
		p := 0;
	    end try;
	    if p ne 0 then
		break;
	    end if;
	end while;
	l := IsIsomorphic(M1K, M2K);
	if not l or not WantT then
	    return true, l, _;
	end if;
    end if;

    //printf "M1 := %m;\n", M1;
    D1 := CompositionFactors(M1);
    if #D1 eq 1 then
	return iso_test_irr(M1, M2, WantT, false);
    end if;

    if assigned M1`Character and Type(M2) eq ModGrp then
	l := M1`Character eq Character(M2);
	if not l or not WantT then
	    return true, l, _;
	end if;
    end if;

    D2 := CompositionFactors(M2);
    //"D1:", D1; "D2:", D2;
    if #D2 eq 1 then
	return true, false, _;
    end if;

    //"D1 char:", [Character(x): x in D1];
    //"D2 char:", [Character(x): x in D2];

    if 0 eq 1 then
	// OFF: can cause infinite recursion
	"GET CONS";
	C1, I1 := ConstituentsWithMultiplicities(M1);
	C2, I2 := ConstituentsWithMultiplicities(M2);

	//"Now C1:", C1; "Now C2:", C2;
	// Series must match in dimensions
	D := [<Dimension(t[1]), t[2]>: t in C1];
	if [<Dimension(t[1]), t[2]>: t in C2] ne D then
	    //"Cons fail";
	    return true, false, _;
	end if;
    end if;

    T1 := <>;
    T2 := <>;
    U := <>;
    for i := 1 to #D1 do
	S1 := D1[i];
	goodj := 0;
	for j := 1 to #D2 do
	    S2 := D2[j];
	    if not quick_non_iso_test(S1, S2) then
		_, l, Tj := iso_test_irr(S1, S2, true, false);
		if l then
		    Remove(~D2, j);
		    goodj := j;
		    Append(~T1, Morphism(S1, M1));
		    Append(~T2, Morphism(S2, M2));
		    Append(~U, Tj);
		    break;
		end if;
	    end if;
	end for;
	if goodj eq 0 then
	    return true, false, _;
	end if;
    end for;

    T1 := VerticalJoin(T1);
    T2 := VerticalJoin(T2);
    U := DiagonalJoin(U);

    R := FieldOfFractions(R);
    T := Matrix(R, T1)^-1 * U * T2;
    T := Matrix(R, T);
    return true, true, T;

    return false, false, _;

end intrinsic;
