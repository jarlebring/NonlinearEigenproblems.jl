#  A Polynomial eigenvalue problem
workspace()
push!(LOAD_PATH, pwd())	# look for modules in the current directory
using NEPSolver
using NEPCore
using PolynomialRoots
#using Polynomial
#using PyPlot

n=200; # mat size
p=3; # Poly degree

A=Array{Float64}(n,n,p)
srand(0)
for i=1:p
   A[:,:,i]=randn(n,n);
end

# Create the derivative function for the PEP
function PEP_Md(λ,i=0)
    # Only workds for i=0 or i=1
    if (i==0)
        M=zeros(n,n)
        for i=1:p
            M+=λ^(i-1)*A[:,:,i]
        end
        return M
    else 
        Mp=zeros(n,n)
        for i=2:p
            Mp += (i-1)*(λ^(i-2)*A[:,:,i])
        end
        return Mp
    end
end

nep=NEP(n,PEP_Md);

nep.rf=function (x; y=x,
                 target=0,
                 λ0=target)
    c=zeros(p)
    for k=1:p
        c[k]=dot(y,A[:,:,k]*x);
    end
    r=roots(c);
    x,index=findmin(abs(r-target))
    return r[index]
end

# Saving the errors in an array
ev=zeros(0)
myerrmeasure=function (λ,v)
    e=nep.relresnorm(λ,v)
    global ev=[ev;e]
    return e
end

# 

println("Running Newton Raphson")
λ,x =newton_raphson(nep,maxit=30,errmeasure=myerrmeasure,displaylevel=1);

λ_exact=λ
ev2=zeros(0)
abserrmeasure=function (λ,v)
    e=abs(λ-λ_exact) # Error measure: abs error in λ 
    global ev2=[ev2;nep.resnorm(λ,v)]
    return e
end
println("Running residual inverse iteration")


λ0=round(λ_exact*10)/10; # Start value
x0=round(x*10)/10;       # Start vector
λ,x =res_inv(nep,λ=λ0,v=x0,
             errmeasure=abserrmeasure,displaylevel=1);	

println("Resnorm of computed solution: ",norm(nep.Md(λ)*x))


## Slow first time it
#Pkg.add("Winston")
#using Winston
#semilogy(ev)
#hold(true)
#semilogy(ev2,"r")
#
## Corresponding code in PyPlot
 #Pkg.add("PyPlot")
#using PyPlot
#semilogy(ev[2:end])
#semilogy(ev2[:])
#ylabel("resnorm");
#xlabel("iteration");